/*
 * Linux helper — system GStreamer only (no vendored FFmpeg).
 *
 *   cc -O2 -o avp_gst avp_gst.c \
 *     $(pkg-config --cflags --libs gstreamer-1.0 gstreamer-pbutils-1.0)
 *
 * Usage:
 *   avp_gst probe <video>
 *   avp_gst extract <video> <outDir> <t1,t2,...>
 *
 * Extract seeks to each timestamp (FLUSH|ACCURATE when possible) then
 * captures one PNG so multi-time samples are not all the first frame.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gst/gst.h>
#include <gst/pbutils/pbutils.h>

static void die(const char *msg) {
  fprintf(stderr, "ERROR: %s\n", msg);
  exit(1);
}

static double probe_duration(const char *path) {
  GError *err = NULL;
  gchar *uri = gst_filename_to_uri(path, &err);
  if (!uri) die(err ? err->message : "uri");
  GstDiscoverer *disc = gst_discoverer_new(5 * GST_SECOND, &err);
  if (!disc) die(err ? err->message : "discoverer");
  GstDiscovererInfo *info = gst_discoverer_discover_uri(disc, uri, &err);
  if (!info) {
    g_free(uri);
    die(err ? err->message : "discover failed");
  }
  GstClockTime dur = gst_discoverer_info_get_duration(info);
  double seconds = (double)dur / (double)GST_SECOND;
  gst_discoverer_info_unref(info);
  g_object_unref(disc);
  g_free(uri);
  if (seconds <= 0 || seconds != seconds) die("invalid duration");
  printf("%.6f\n", seconds);
  return seconds;
}

static void extract_one(const char *path, const char *outpng, double t) {
  GError *err = NULL;
  gchar *uri = gst_filename_to_uri(path, &err);
  if (!uri) die(err ? err->message : "uri");

  gchar *descr = g_strdup_printf(
      "uridecodebin uri=%s ! videoconvert ! videoscale ! "
      "video/x-raw,format=RGB ! pngenc snapshot=true ! filesink location=%s",
      uri, outpng);
  g_free(uri);

  GstElement *pipeline = gst_parse_launch(descr, &err);
  g_free(descr);
  if (!pipeline) die(err ? err->message : "parse_launch");

  /* Preroll then seek, then run until EOS / error so each timestamp differs. */
  gst_element_set_state(pipeline, GST_STATE_PAUSED);
  GstStateChangeReturn scr =
      gst_element_get_state(pipeline, NULL, NULL, 10 * GST_SECOND);
  if (scr == GST_STATE_CHANGE_FAILURE) {
    gst_object_unref(pipeline);
    die("preroll failed");
  }

  gint64 pos = (gint64)(t * (double)GST_SECOND);
  gboolean ok = gst_element_seek_simple(
      pipeline, GST_FORMAT_TIME,
      (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE), pos);
  if (!ok) {
    ok = gst_element_seek_simple(
        pipeline, GST_FORMAT_TIME,
        (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT), pos);
  }
  if (!ok) {
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    die("seek failed");
  }

  /* Wait for seek to finish */
  gst_element_get_state(pipeline, NULL, NULL, 5 * GST_SECOND);

  gst_element_set_state(pipeline, GST_STATE_PLAYING);
  GstBus *bus = gst_element_get_bus(pipeline);
  GstMessage *msg = gst_bus_timed_pop_filtered(
      bus, 15 * GST_SECOND,
      (GstMessageType)(GST_MESSAGE_ERROR | GST_MESSAGE_EOS | GST_MESSAGE_ASYNC_DONE));
  if (msg) {
    if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
      GError *e = NULL;
      gchar *dbg = NULL;
      gst_message_parse_error(msg, &e, &dbg);
      fprintf(stderr, "ERROR: %s\n", e ? e->message : "gst error");
      if (dbg) g_free(dbg);
      if (e) g_error_free(e);
      gst_message_unref(msg);
      gst_object_unref(bus);
      gst_element_set_state(pipeline, GST_STATE_NULL);
      gst_object_unref(pipeline);
      exit(1);
    }
    gst_message_unref(msg);
  }
  /* Drain briefly for pngenc */
  msg = gst_bus_timed_pop_filtered(
      bus, 2 * GST_SECOND,
      (GstMessageType)(GST_MESSAGE_ERROR | GST_MESSAGE_EOS));
  if (msg) gst_message_unref(msg);

  gst_object_unref(bus);
  gst_element_set_state(pipeline, GST_STATE_NULL);
  gst_object_unref(pipeline);

  /* Verify file exists */
  FILE *fp = fopen(outpng, "rb");
  if (!fp) die("output png missing after extract");
  fseek(fp, 0, SEEK_END);
  long sz = ftell(fp);
  fclose(fp);
  if (sz < 32) die("output png too small");
}

int main(int argc, char **argv) {
  gst_init(&argc, &argv);
  if (argc < 3) die("usage: avp_gst probe|extract ...");
  if (strcmp(argv[1], "probe") == 0) {
    probe_duration(argv[2]);
    return 0;
  }
  if (strcmp(argv[1], "extract") == 0) {
    if (argc < 5) die("extract video outDir timesCsv");
    const char *path = argv[2];
    const char *outdir = argv[3];
    char *csv = g_strdup(argv[4]);
    char *saveptr = NULL;
    char *tok = strtok_r(csv, ",", &saveptr);
    int index = 1;
    while (tok) {
      double t = atof(tok);
      char outpng[4096];
      snprintf(outpng, sizeof(outpng), "%s/frame-%04d.png", outdir, index);
      extract_one(path, outpng, t);
      printf("%d\t%.6f\tframe-%04d.png\n", index, t, index);
      index++;
      tok = strtok_r(NULL, ",", &saveptr);
    }
    g_free(csv);
    return 0;
  }
  die("unknown command");
  return 1;
}
