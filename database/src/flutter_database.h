#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifndef FLUTTER_DATABASE_H
#define FLUTTER_DATABASE_H

FFI_PLUGIN_EXPORT struct Dart_Task {
    int list_id;
    int id;
    char* uuid;
    char* title;
    char* description;
    char* startDate;
    char* endDate;
    int status;
};

FFI_PLUGIN_EXPORT struct Dart_TaskList {
    int id;
    char* uuid;
    char* title;
};

// Dart API functions
FFI_PLUGIN_EXPORT int Dart_init();
FFI_PLUGIN_EXPORT int Dart_exit();
FFI_PLUGIN_EXPORT int Dart_get_list_pre();
FFI_PLUGIN_EXPORT int Dart_get_task_pre();
FFI_PLUGIN_EXPORT struct Dart_TaskList Dart_get_list();
FFI_PLUGIN_EXPORT struct Dart_Task Dart_get_task();
FFI_PLUGIN_EXPORT int Dart_create_tasklist(const char* list_name);
FFI_PLUGIN_EXPORT int Dart_create_task(int list_id, const char* title, const char* description,
                    const char* startDate, const char* endDate, int status);
FFI_PLUGIN_EXPORT int Dart_update_task(int list_id, int task_id, const char* title,
                    const char* description, const char* startDate,
                    const char* endDate, int status);
FFI_PLUGIN_EXPORT int Dart_update_tasklist(int list_id, const char* title);
FFI_PLUGIN_EXPORT int Dart_delete_task(int task_id);
FFI_PLUGIN_EXPORT int Dart_delete_tasklist(int list_id);

FFI_PLUGIN_EXPORT int Dart_query_tasklist_by_uuid(const char* uuid, Dart_TaskList* result);
FFI_PLUGIN_EXPORT int Dart_query_task_by_uuid(const char* uuid, Dart_Task* result);
FFI_PLUGIN_EXPORT int Dart_delete_tasklist_by_uuid(const char* uuid);
FFI_PLUGIN_EXPORT int Dart_delete_task_by_uuid(const char* uuid);

[[deprecated]] FFI_PLUGIN_EXPORT int Dart_query_tasklist_num();
[[deprecated]] FFI_PLUGIN_EXPORT int Dart_query_tasklist_id(int num);
[[deprecated]] FFI_PLUGIN_EXPORT char* Dart_query_tasklist_name(int id);
[[deprecated]] FFI_PLUGIN_EXPORT int Dart_query_task_num(int task_num); // why the name was
// [[deprecated]] FFI_PLUGIN_EXPORT struct Dart_Task Dart_get_task(int list_num, int task_num);
[[deprecated]] FFI_PLUGIN_EXPORT int Dart_update_task_stat(int list_id, int task_id, int stat);
[[deprecated]] FFI_PLUGIN_EXPORT int Dart_move_task(int list_id, int task_id, int to_list_id);

#endif