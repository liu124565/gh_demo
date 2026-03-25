#include "taskbar_hide.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#endif

using namespace godot;

void TaskbarHide::_bind_methods() {
	ClassDB::bind_method(D_METHOD("apply_toolwindow", "hwnd"), &TaskbarHide::apply_toolwindow);
	ClassDB::bind_method(D_METHOD("restore_appwindow", "hwnd"), &TaskbarHide::restore_appwindow);
	ClassDB::bind_method(D_METHOD("hide_window", "hwnd"), &TaskbarHide::hide_window);
	ClassDB::bind_method(D_METHOD("show_window", "hwnd"), &TaskbarHide::show_window);
	ClassDB::bind_method(D_METHOD("force_activate_window", "hwnd"), &TaskbarHide::force_activate_window);
}

#ifdef _WIN32
static bool update_exstyle(HWND hwnd, LONG_PTR add_flags, LONG_PTR remove_flags) {
	if (hwnd == nullptr) {
		return false;
	}

	LONG_PTR exstyle = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
	LONG_PTR new_exstyle = (exstyle | add_flags) & ~remove_flags;
	if (new_exstyle == exstyle) {
		return true;
	}

	SetWindowLongPtrW(hwnd, GWL_EXSTYLE, new_exstyle);
	SetWindowPos(
		hwnd,
		nullptr,
		0,
		0,
		0,
		0,
		SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_NOOWNERZORDER
	);
	// Avoid hide/show here to prevent visible flicker on transparent windows.
	return true;
}
#endif

bool TaskbarHide::apply_toolwindow(int64_t hwnd) {
#ifdef _WIN32
	return update_exstyle(reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd)), WS_EX_TOOLWINDOW, WS_EX_APPWINDOW);
#else
	return false;
#endif
}

bool TaskbarHide::restore_appwindow(int64_t hwnd) {
#ifdef _WIN32
	return update_exstyle(reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd)), WS_EX_APPWINDOW, WS_EX_TOOLWINDOW);
#else
	return false;
#endif
}

bool TaskbarHide::hide_window(int64_t hwnd) {
#ifdef _WIN32
	HWND target = reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd));
	if (target == nullptr) {
		return false;
	}

	update_exstyle(target, WS_EX_TOOLWINDOW, WS_EX_APPWINDOW);
	ShowWindow(target, SW_HIDE);
	return !IsWindowVisible(target);
#else
	return false;
#endif
}

bool TaskbarHide::show_window(int64_t hwnd) {
#ifdef _WIN32
	HWND target = reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd));
	if (target == nullptr) {
		return false;
	}

	update_exstyle(target, WS_EX_TOOLWINDOW, WS_EX_APPWINDOW);
	ShowWindow(target, SW_SHOWNORMAL);
	return IsWindowVisible(target) != FALSE;
#else
	return false;
#endif
}

bool TaskbarHide::force_activate_window(int64_t hwnd) {
#ifdef _WIN32
	HWND target = reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd));
	if (target == nullptr) {
		return false;
	}

	HWND foreground = GetForegroundWindow();
	DWORD target_thread = GetWindowThreadProcessId(target, nullptr);
	DWORD foreground_thread = foreground != nullptr ? GetWindowThreadProcessId(foreground, nullptr) : 0;
	bool attached = false;

	if (foreground_thread != 0 && foreground_thread != target_thread) {
		attached = AttachThreadInput(foreground_thread, target_thread, TRUE) != FALSE;
	}

	ShowWindow(target, SW_SHOWNORMAL);
	BringWindowToTop(target);
	SetForegroundWindow(target);
	SetActiveWindow(target);
	SetFocus(target);

	if (attached) {
		AttachThreadInput(foreground_thread, target_thread, FALSE);
	}

	return GetForegroundWindow() == target || GetActiveWindow() == target || GetFocus() == target;
#else
	return false;
#endif
}
