//
// Created by kibi on 25-1-10.
//

#ifndef DATABASE_H
#define DATABASE_H

#include <string>
#include <vector>
#include <random>
#include <sstream>
#include <iomanip>
#include "sqlite3.h"

extern "C" {
#include "flutter_database.h"
}

using uint = unsigned int;
using std::string, std::vector;

// UUID生成器类
class UUIDGenerator {
private:
    static std::random_device rd;
    static std::mt19937 gen;
    static std::uniform_int_distribution<> dis;

public:
    static string generate();
};

class Database
{
    sqlite3 *database;
    uint task_list_id;
    uint task_list_num;
    uint task_id;
    uint task_num;
    int run_sql_cmd(const char* sql_cmd, int (*)(void*, int, char**, char**), void*);

public:
    class Task {
        const uint id;
        const string uuid;  // 添加UUID
        bool fresh;
        friend Database;
        explicit Task(const uint id) : id(id), uuid(UUIDGenerator::generate()), fresh(false), belong(0), start_time(0), end_time(0), status(0) {}
        explicit Task(const uint id, const string& uuid) : id(id), uuid(uuid), fresh(false), belong(0), start_time(0), end_time(0), status(0) {}
    public:
        Task(const Task& task) : id(task.id), uuid(task.uuid), fresh(false), belong(task.belong), title(task.title), description(task.description), start_time(task.start_time), end_time(task.end_time), status(task.status) {}
        uint belong;
        string title;
        string description;
        long long start_time;
        long long end_time;
        int status;

        [[nodiscard]] uint get_id() const {
            return id;
        }

        [[nodiscard]] const string& get_uuid() const {
            return uuid;
        }
    };

    class TaskList {
        const uint id;
        const string uuid;  // 添加UUID
        bool fresh;
        friend Database;
        explicit TaskList(const uint id) : id(id), uuid(UUIDGenerator::generate()), fresh(false) {}
        explicit TaskList(const uint id, const string& uuid) : id(id), uuid(uuid), fresh(false) {}
    public:
        TaskList(const TaskList& task_list) : id(task_list.id), uuid(task_list.uuid), fresh(false), title(task_list.title) {}
        string title;

        [[nodiscard]] uint get_id() const {
            return id;
        }

        [[nodiscard]] const string& get_uuid() const {
            return uuid;
        }
    };

    explicit Database(const string& file_path);
    ~Database();

    int new_task_list(TaskList*& task_list);
    int new_task(Task*& task);
    int add_task_list(TaskList* list);
    int delete_task_list(uint id);
    int delete_task_list_by_uuid(const string& uuid);  // 新增：通过UUID删除
    int query_task_list_num(uint&) const;
    int query_task_list(uint id, TaskList*&);
    int query_task_list_by_uuid(const string& uuid, TaskList*&);  // 新增：通过UUID查询
    int query_all_task_list(vector<TaskList>&);
    int update_task_list(const TaskList& task_list);

    int add_task(Task* task);
    int delete_task(uint id);
    int delete_task_by_uuid(const string& uuid);  // 新增：通过UUID删除
    int query_task_num(uint&) const;
    int query_task(uint id, Task*&);
    int query_task_by_uuid(const string& uuid, Task*&);  // 新增：通过UUID查询
    int query_all_task(vector<Task>&);
    int update_task(const Task& task);
};

namespace Utility {
    string time_to_string(time_t time);
    long long string_to_time(const std::string& time);
    Dart_Task task_to_dart_task(const Database::Task&);
    Dart_TaskList list_to_dart_task_list(const Database::TaskList&);
};

#endif //DATABASE_H
