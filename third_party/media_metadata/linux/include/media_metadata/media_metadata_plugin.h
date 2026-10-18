#ifndef FLUTTER_PLUGIN_MEDIA_METADATA_PLUGIN_H_
#define FLUTTER_PLUGIN_MEDIA_METADATA_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

// Add these boilerplate typedefs:
typedef struct _MediaMetadataPlugin MediaMetadataPlugin;
typedef struct _MediaMetadataPluginClass MediaMetadataPluginClass;

// Add the type getter declaration needed by G_DEFINE_TYPE:
FLUTTER_PLUGIN_EXPORT GType media_metadata_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void media_metadata_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_MEDIA_METADATA_PLUGIN_H_
