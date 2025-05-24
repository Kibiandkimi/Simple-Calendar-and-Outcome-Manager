//
// Created by kibi on 25-1-30.
//

#include <sstream>

int Database::new_task_list(TaskList*& task_list) {
    std::stringstream ss;
    ss << "UPDATE META SET VALUE = '" << task_list_id + 1 << "' WHERE NAME = 'LIST_ID';";
    int code = run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
    if (code == 0) {
        task_list = new TaskList{++task_list_id};
        task_list->fresh = true;
        return 0;
    }
    return code;
}

int Database::add_task_list(TaskList* list) {
    if (!list->fresh) return -2;
    std::stringstream ss;
    ss << "INSERT INTO LISTS VALUES(" << list->id << ", '" << list->title << "', '" << 0 << "');";
    int code = run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
    if (code == 0) {
        task_list_num++;
        delete list;
    }
    return code;
}

int Database::delete_task_list(uint id) {
    std::stringstream ss;
    ss << "DELETE FROM LISTS WHERE ID = '" << id << "';";
    int code = run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
    if (code == 0) {
        task_list_num--;
        int delete_task_num;
        ss.str("");
        ss << "SELECT COUNT(*) FROM TASKS WHERE BELONG = '" << id << "';";
        run_sql_cmd(ss.str().c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
            *static_cast<int*>(data) = std::stoi(argv[0]);
            return 0;
        }, &delete_task_num);
        task_num -= delete_task_num;
        ss.str("");
        ss << "DELETE FROM TASKS WHERE BELONG = '" << id << "';";
        code = run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
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
    std::stringstream ss;
    ss << "SELECT TITLE FROM LISTS WHERE ID = '" << id << "';";
    return run_sql_cmd(ss.str().c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
        static_cast<TaskList*>(data)->title = argv[0];
        return 0;
    }, task_list);
}

int Database::query_all_task_list(vector<TaskList>& task_lists) {
    return run_sql_cmd("SELECT * FROM LISTS;", [](void* data, int argc, char** argv, char** colName) -> int {
        static_cast<vector<TaskList>*>(data)->push_back(TaskList{static_cast<uint>(std::stoi(argv[0]))});
        static_cast<vector<TaskList>*>(data)->back().title = argv[1];
        return 0;
    }, &task_lists);
}

int Database::update_task_list(const TaskList& task_list) {
    std::stringstream ss;
    ss << "UPDATE LISTS SET TITLE = '" << task_list.title << "' WHERE ID = '" << task_list.id << "';";
    return run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
}

int Database::new_task(Task*& task) {
    std::stringstream ss;
    ss << "UPDATE META SET VALUE = '" << task_id + 1 << "' WHERE NAME = 'TASK_ID';";
    int code = run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
    if (code == 0) {
        task = new Task{++task_id};
        task->fresh = true;
        return 0;
    }
    return code;
}

int Database::add_task(Task* task) {
    if (!task->fresh) return -2;
    std::stringstream ss;
    ss << "INSERT INTO TASKS VALUES(" << task->id << ", " << task->belong << ", '" << task->title << "', '" << task->description << "', " << task->start_time << ", " << task->end_time << ", " << task->status << ");";
    int code = run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
    if (code == 0) {
        task_num++;
        delete task;
    }
    return code;
}

int Database::delete_task(uint id) {
    std::stringstream ss;
    ss << "DELETE FROM TASKS WHERE ID = '" << id << "';";
    int code = run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
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
    std::stringstream ss;
    ss << "SELECT BELONG, TITLE, DESCRIPTION, START_TIME, END_TIME, STATUS FROM TASKS WHERE ID = '" << id << "';";
    return run_sql_cmd(ss.str().c_str(), [](void* data, int argc, char** argv, char** colName) -> int {
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
    return run_sql_cmd("SELECT * FROM TASKS;", [](void* data, int argc, char** argv, char** colName) -> int {
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
    std::stringstream ss;
    ss << "UPDATE TASKS SET BELONG = " << task.belong << ", TITLE = '" << task.title << "', DESCRIPTION = '" << task.description << "', START_TIME = " << task.start_time << ", END_TIME = " << task.end_time << ", STATUS = " << task.status << " WHERE ID = '" << task.id << "';";
    return run_sql_cmd(ss.str().c_str(), nullptr, nullptr);
}