#include "database.h"

#include <chrono>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <string>
#include <sstream> // for macOS
#include "sqlite3.h"

#include "easylogging++.h"

INITIALIZE_EASYLOGGINGPP

using std::stoi;
using Task = Database::Task;
using TaskList = Database::TaskList;

int Database::run_sql_cmd(const char* sql_cmd, int(* callback)(void*, int, char**, char**), void* data) {
    LOG(DEBUG) << "Running SQL Command: " << sql_cmd;

    char* errMsg = nullptr;
    int rc = sqlite3_exec(database, sql_cmd, callback, data, &errMsg);

    if (rc != SQLITE_OK) {
        LOG(ERROR) << "SQL Command Failed!";
        LOG(ERROR) << "Error Message: " << errMsg;
        sqlite3_free(errMsg);
        return -1;
    }

    return 0;
}

// TODO: Upgrade from older version
Database::Database(const string& file_path) {
    LOG(DEBUG) << "Database constructing.";
    if (sqlite3_open(file_path.c_str(), &database)) {
        LOG(ERROR) << "Cannot open database: " + string(sqlite3_errmsg(database));
        throw std::runtime_error("Cannot open database!");
    }

    run_sql_cmd("CREATE TABLE IF NOT EXISTS LISTS(ID INTEGER PRIMARY KEY, TITLE TEXT NOT NULL, TASK_NUM INTEGER NOT NULL);", nullptr, nullptr);
    run_sql_cmd("CREATE TABLE IF NOT EXISTS TASKS(ID INTEGER PRIMARY KEY, BELONG INTEGER NOT NULL, TITLE TEXT NOT NULL, DESCRIPTION TEXT, START_TIME INTEGER NOT NULL, END_TIME INTEGER NOT NULL, STATUS INTEGER NOT NULL);", nullptr, nullptr);
    run_sql_cmd("CREATE TABLE IF NOT EXISTS META(NAME TEXT PRIMARY KEY, VALUE INTEGER);", nullptr, nullptr);

    int version = -1;

    run_sql_cmd("SELECT VALUE FROM META WHERE NAME = 'VERSION';", [](void* data, int argc, char** argv, char** colName) -> int {
        *static_cast<int*>(data) = std::stoi(argv[0]);
        return 0;
    }, &version);

    if (version == -1) {
        run_sql_cmd("INSERT INTO META VALUES ('VERSION', '3');", nullptr, nullptr);
        run_sql_cmd("INSERT INTO META VALUES ('LIST_ID', '0');", nullptr, nullptr);
        run_sql_cmd("INSERT INTO META VALUES ('TASK_ID', '0');", nullptr, nullptr);
        task_list_id = task_list_num = task_id = task_num = 0;
        return;
    }
    if (version != 3) {
        LOG(ERROR) << "Unexpected database version!";
        throw std::runtime_error("Error: unexpected database version!");
    }

    run_sql_cmd("SELECT VALUE FROM META WHERE NAME = 'LIST_ID';", [](void* data, int argc, char** argv, char** colName) -> int {
        *static_cast<uint*>(data) = std::stoi(argv[0]);
        return 0;
    }, &task_list_id);
    run_sql_cmd("SELECT COUNT(*) FROM LISTS;", [](void* data, int argc, char** argv, char** colName) -> int {
        *static_cast<uint*>(data) = std::stoi(argv[0]);
        return 0;
    }, &task_list_num);
    run_sql_cmd("SELECT VALUE FROM META WHERE NAME = 'TASK_ID';", [](void* data, int argc, char** argv, char** colName) -> int {
        *static_cast<uint*>(data) = std::stoi(argv[0]);
        return 0;
    }, &task_id);
    run_sql_cmd("SELECT COUNT(*) FROM TASKS;", [](void* data, int argc, char** argv, char** colName) -> int {
        *static_cast<uint*>(data) = std::stoi(argv[0]);
        return 0;
    }, &task_num);

}

Database::~Database() {
    sqlite3_close(database);
}

#ifdef MACOS
    #include "database_macos.cpp"
#else

using std::format;

int Database::new_task_list(TaskList*& task_list) {
    int code = run_sql_cmd(std::format("UPDATE META SET VALUE = '{}' WHERE NAME = 'LIST_ID';", task_list_id + 1).c_str(), nullptr, nullptr);
    if (code == 0) {
        task_list = new TaskList{++task_list_id};
        task_list->fresh = true;
        return 0;
    }
    return code;
}

int Database::add_task_list(TaskList* list) {
    if (!list->fresh) return -2;
    int code = run_sql_cmd(std::format("INSERT INTO LISTS VALUES({}, '{}', '{}');", list->id, list->title, 0).c_str(), nullptr, nullptr);
    if (code == 0) {
        task_list_num++;
        delete list;
    }
    return code;
}

int Database::delete_task_list(uint id) {
    int code = run_sql_cmd(std::format("DELETE FROM LISTS WHERE ID = '{}';", id).c_str(), nullptr, nullptr);
    if (code == 0) {
        task_list_num--;
        int delete_task_num;
        run_sql_cmd(format("SELECT COUNT(*) FROM TASKS WHERE BELONG = '{}';", id).c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
            *static_cast<int*>(data) = std::stoi(argv[0]);
            return 0;
        }, &delete_task_num);
        task_num -= delete_task_num;
        code = run_sql_cmd(format("DELETE FROM TASKS WHERE BELONG = '{}';", id).c_str(), nullptr, nullptr);
        return code == 0 ? 0 : -1;
    }
    return code;
}

int Database::query_task_list_num(uint& num) const {
    num = task_list_num;
    return 0;
}

int Database::query_task_list(uint id, TaskList*& task_list) {
    task_list = new TaskList{id};
    return run_sql_cmd(format("SELECT TITLE FROM LISTS WHERE ID = '{}';", id).c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
        static_cast<TaskList*>(data)->title = argv[0];
        return 0;
    }, task_list);
}

int Database::query_all_task_list(vector<TaskList>& task_lists) {
    return run_sql_cmd(format("SELECT * FROM LISTS;").c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
        static_cast<vector<TaskList>*>(data)->push_back(TaskList{static_cast<uint>(std::stoi(argv[0]))});
        static_cast<vector<TaskList>*>(data)->back().title = argv[1];
        return 0;
    }, &task_lists);
}

int Database::update_task_list(const TaskList& task_list) {
    return run_sql_cmd(format("UPDATE LISTS SET TITLE = '{}' WHERE ID = '{}';", task_list.title, task_list.id).c_str(), nullptr, nullptr);
}

int Database::new_task(Task*& task) {
    int code = run_sql_cmd(std::format("UPDATE META SET VALUE = '{}' WHERE NAME = 'TASK_ID';", task_id + 1).c_str(), nullptr, nullptr);
    if (code == 0) {
        task = new Task{++task_id};
        task->fresh = true;
        return 0;
    }
    return code;
}

int Database::add_task(Task* task) {
    if (!task->fresh) return -2;
    int code = run_sql_cmd(format("INSERT INTO TASKS VALUES({}, {}, '{}', '{}', {}, {}, {});", task->id, task->belong, task->title, task->description, task->start_time, task->end_time, task->status).c_str(), nullptr, nullptr);
    if (code == 0) {
        task_num++;
        delete task;
    }
    return code;
}

int Database::delete_task(uint id) {
    int code = run_sql_cmd(format("DELETE FROM TASKS WHERE ID = '{}';", id).c_str(), nullptr, nullptr);
    if (code == 0) {
        task_num--;
        return 0;
    }
    return code;
}

int Database::query_task_num(uint& num) const {
    num = task_num;
    return 0;
}

int Database::query_task(uint id, Task*& task) {
    task = new Task{id};
    return run_sql_cmd(format("SELECT BELONG, TITLE, DESCRIPTION, START_TIME, END_TIME, STATUS FROM TASKS WHERE ID = '{}';", id).c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
        static_cast<Task*>(data)->belong = std::stoi(argv[0]);
        static_cast<Task*>(data)->title = argv[1];
        static_cast<Task*>(data)->description = argv[2];
        static_cast<Task*>(data)->start_time = std::stoll(argv[3]);
        static_cast<Task*>(data)->end_time = std::stoll(argv[4]);
        static_cast<Task*>(data)->status = std::stoi(argv[5]);
        return 0;
    }, task);
}

int Database::query_all_task(vector<Task>& tasks) {
    return run_sql_cmd(format("SELECT * FROM TASKS;").c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
        static_cast<vector<Task>*>(data)->push_back(Task{static_cast<uint>(std::stoi(argv[0]))});
        static_cast<vector<Task>*>(data)->back().belong = std::stoi(argv[1]);
        static_cast<vector<Task>*>(data)->back().title = argv[2];
        static_cast<vector<Task>*>(data)->back().description = argv[3];
        static_cast<vector<Task>*>(data)->back().start_time = std::stoll(argv[4]);
        static_cast<vector<Task>*>(data)->back().end_time = std::stoll(argv[5]);
        static_cast<vector<Task>*>(data)->back().status = std::stoi(argv[6]);
        return 0;
    }, &tasks);
}

int Database::update_task(const Task& task) {
    return run_sql_cmd(format("UPDATE TASKS SET BELONG = {}, TITLE = '{}', DESCRIPTION = '{}', START_TIME = {}, END_TIME = {}, STATUS = {} WHERE ID = '{}';", task.belong, task.title, task.description, task.start_time, task.end_time, task.status, task.id).c_str(), nullptr, nullptr);
}

#endif

#ifdef __ANDROID__
    #include "database_android.cpp"
#else
    #define PLATFORM_ANDROID 0
#endif

string Utility::time_to_string(const time_t time) {
    const std::tm* tm = std::localtime(&time);
    std::stringstream ss;
    ss << std::put_time(tm, "%Y-%m-%d %H:%M:%S");
    return ss.str();
}

long long Utility::string_to_time(const std::string& time) {
    std::tm tm = {};
    std::istringstream ss(time);
    ss >> std::get_time(&tm, "%Y-%m-%d %H:%M:%S");
    return mktime(&tm);
}

Dart_Task Utility::task_to_dart_task(const Task& task) {
    Dart_Task dart_task{};
    dart_task.list_id = task.belong;
    dart_task.id = task.get_id();

    dart_task.title = new char[task.title.length() + 1];
    strcpy(dart_task.title, task.title.c_str());
    dart_task.description = new char[task.description.length() + 1];
    strcpy(dart_task.description, task.description.c_str());
    auto start_date = time_to_string(task.start_time);
    dart_task.startDate = new char[start_date.length() + 1];
    strcpy(dart_task.startDate, start_date.c_str());
    auto end_date = time_to_string(task.end_time);
    dart_task.endDate = new char[end_date.length() + 1];
    strcpy(dart_task.endDate, end_date.c_str());

    dart_task.status = task.status;
    return dart_task;
}

Dart_TaskList Utility::list_to_dart_task_list(const TaskList& list) {
    Dart_TaskList dart_task_list{};
    dart_task_list.id = list.get_id();
    dart_task_list.title = new char[list.title.length() + 1];
    strcpy(dart_task_list.title, list.title.c_str());
    return dart_task_list;
}

Database* db = nullptr;
bool inited = false;
int Dart_init() {
    if (inited) {
        LOG(WARNING) << "Repeated init.";
        return -2;
    }

    std::string path;

    #ifdef __ANDROID__
        LOG(INFO) << "Android init.";
        path = get_database_path();
        LOG(DEBUG) << "Android path:" << path;
        // throw std::runtime_error("Detect Andriod Successful!");
    #else
        path = "tasks.db";
    #endif

    db = new Database(path);
    inited = true;
    LOG(DEBUG) << "Init finished.";

    return 0;
}

namespace DartData {
    bool list_pre = false;
    uint list_num;
    uint list_cnt;
    vector<TaskList> lists;
    bool task_pre = false;
    uint task_num;
    uint task_cnt;
    vector<Task> tasks;
}

using namespace DartData;
using namespace Utility;

int Dart_get_list_pre() {
    if(inited && !list_pre) {
        db->query_task_list_num(list_num);
        db->query_all_task_list(lists);
        list_cnt = 0;
        list_pre = true;
        LOG(DEBUG) << "List preloaded.";
        return static_cast<int>(list_num);
    }
    LOG(ERROR) << "No inited or already preloaded.";
    return -1;
}

int Dart_get_task_pre() {
    if (inited && !task_pre) {
        db->query_task_num(task_num);
        db->query_all_task(tasks);
        task_cnt = 0;
        task_pre = true;
        LOG(DEBUG) << "Task preloaded.";
        return static_cast<int>(task_num);
    }
    LOG(ERROR) << "No inited or already preloaded.";
    return -1;
}

Dart_TaskList Dart_get_list() {
    if (list_pre && list_cnt < list_num) {
        return list_to_dart_task_list(lists[list_cnt++]);
    }
    LOG(ERROR) << "No preloaded or already finished.";
    return Dart_TaskList{};
}

Dart_Task Dart_get_task() {
    if (task_pre && task_cnt < task_num) {
        return task_to_dart_task(tasks[task_cnt++]);
    }
    LOG(ERROR) << "No preloaded or already finished.";
    return Dart_Task{};
}

int Dart_create_tasklist(const char* list_name) {
    if (inited) {
        TaskList *list;
        db->new_task_list(list);
        list->title = list_name;
        int id = static_cast<int>(list->get_id());
        db->add_task_list(list);
        return id;
    }
    LOG(ERROR) << "No inited.";
    return -1;
}

int Dart_create_task(int list_id, const char* title, const char* description, const char* startDate,
                              const char* endDate, int status) {
    if (inited) {
        Task *task;
        db->new_task(task);
        task->belong = list_id,
        task->title = title,
        task->description = description,
        task->start_time = string_to_time(startDate),
        task->end_time = string_to_time(endDate),
        task->status = status;
        int id = static_cast<int>(task->get_id());
        db->add_task(task);
        return id;
    }
    LOG(ERROR) << "No inited.";
    return -1;
}

int Dart_update_task(int list_id, int task_id, const char* title, const char* description,
                              const char* startDate, const char* endDate, int status) {
    if (inited) {
        Task *task;
        db->query_task(task_id, task);
        task->belong = list_id,
        task->title = title,
        task->description = description,
        task->start_time = string_to_time(startDate),
        task->end_time = string_to_time(endDate),
        task->status = status;
        db->update_task(*task);
        return 0;
    }
    LOG(ERROR) << "No inited.";
    return -1;
}

int Dart_delete_task(int task_id) {
    if (inited) {
        db->delete_task(task_id);
        return 0;
    }
    LOG(ERROR) << "No inited.";
    return -1;
}

int Dart_delete_tasklist(int list_id) {
    if(inited) {
        db->delete_task_list(list_id);
        return 0;
    }
    LOG(ERROR) << "No inited.";
    return -1;
}

int Dart_query_tasklist_num() {
    LOG(WARNING) << "Function has been deprecated.";
    uint ret = -1;
    db->query_task_list_num(ret);
    return static_cast<int>(ret);
}

int Dart_query_tasklist_id(int num) {
    LOG(ERROR) << "Function has been deleted.";
    // throw std::runtime_error("Function has been deleted.");
    return -1;
}

char* Dart_query_tasklist_name(int id) {
    LOG(WARNING) << "Function has been deprecated.";
    TaskList *list;
    db->query_task_list(id, list);
    char* ret = new char[list->title.length() + 1];
    strcpy(ret, list->title.c_str());
    return ret;
}

int Dart_query_task_num(int task_num) {
    LOG(ERROR) << "Function has been deleted.";
    // throw std::runtime_error("Function has been deleted.");
    return -1;
}

int Dart_update_task_stat(int list_id, int task_id, int stat) {
    LOG(WARNING) << "Function has been deprecated.";
    Task *task;
    db->query_task(task_id, task);
    task->status = stat;
    db->update_task(*task);
    return 0;
}

int Dart_move_task(int list_id, int task_id, int to_list_id) {
    LOG(WARNING) << "Function has been deprecated.";
    Task *task;
    db->query_task(task_id, task);
    task->belong = to_list_id;
    db->update_task(*task);
    return 0;
}