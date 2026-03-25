#ifndef TASKBAR_HIDE_H
#define TASKBAR_HIDE_H

#include <godot_cpp/classes/object.hpp>

class TaskbarHide : public godot::Object {
	GDCLASS(TaskbarHide, godot::Object);

public:
	bool apply_toolwindow(int64_t hwnd);
	bool restore_appwindow(int64_t hwnd);
	bool hide_window(int64_t hwnd);
	bool show_window(int64_t hwnd);
	bool force_activate_window(int64_t hwnd);

protected:
	static void _bind_methods();
};

#endif
