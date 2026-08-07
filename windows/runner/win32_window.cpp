#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// Brand colors for the native splash (matches the Flutter theme):
// deep navy background, indigo accent, off-white foreground.
constexpr COLORREF kSplashDark = RGB(13, 21, 38);       // #0D1526
constexpr COLORREF kSplashAccent = RGB(79, 70, 229);    // #4F46E5
constexpr COLORREF kSplashWhite = RGB(245, 245, 247);   // #F5F5F7
constexpr COLORREF kSplashGrey = RGB(168, 176, 194);    // #A8B0C2

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  ShowWindow(window_handle_, SW_SHOWNORMAL);
  return UpdateWindow(window_handle_) != 0;
}

void Win32Window::ShowSplashImmediately() {
  ShowWindow(window_handle_, SW_SHOWNORMAL);
  // Paint the splash right now, not when the message loop eventually runs.
  // UpdateWindow synchronously delivers WM_PAINT to the window proc, so the
  // logo is visible while the Flutter engine is still booting.
  RedrawWindow(window_handle_, nullptr, nullptr,
               RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_ERASEBKGND:
      // We paint the full splash in WM_PAINT (below) to avoid flicker while
      // the Flutter view is not attached yet.
      if (child_content_ == nullptr) {
        return 1;
      }
      break;

    case WM_PAINT:
      // Draw the brand splash over the otherwise blank window until the first
      // Flutter frame is attached as the child content.
      if (child_content_ == nullptr) {
        PaintSplash(hwnd);
        return 0;
      }
      break;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}

void Win32Window::PaintSplash(HWND window) {
  PAINTSTRUCT ps;
  HDC hdc = BeginPaint(window, &ps);

  RECT rc;
  GetClientRect(window, &rc);
  const int width = rc.right - rc.left;
  const int height = rc.bottom - rc.top;

  // Deep navy background.
  HBRUSH bg = CreateSolidBrush(kSplashDark);
  FillRect(hdc, &rc, bg);
  DeleteObject(bg);

  // Scale proportions relative to a 1280x720 reference window.
  double f = static_cast<double>(height) / 720.0;
  if (f < 0.6) f = 0.6;
  if (f > 2.0) f = 2.0;

  const int cx = width / 2;
  const int cy = height / 2;
  const int circleRadius = static_cast<int>(78 * f);
  const int centerCy = cy - static_cast<int>(28 * f);

  // Indigo accent circle behind the graduation cap.
  HBRUSH accent = CreateSolidBrush(kSplashAccent);
  HGDIOBJ oldBrush = SelectObject(hdc, accent);
  HGDIOBJ oldPen = SelectObject(hdc, CreatePen(PS_SOLID, 0, kSplashAccent));
  Ellipse(hdc, cx - circleRadius, centerCy - circleRadius,
          cx + circleRadius, centerCy + circleRadius);

  // Graduation cap: a rotated square ("diamond") board.
  const int dx = static_cast<int>(circleRadius * 0.62);
  const int topDy = static_cast<int>(circleRadius * 0.42);
  const int botDy = static_cast<int>(circleRadius * 0.16);
  POINT cap[4] = {
      {cx, centerCy - topDy},
      {cx + dx, centerCy},
      {cx, centerCy + botDy},
      {cx - dx, centerCy},
  };
  HBRUSH white = CreateSolidBrush(kSplashWhite);
  HPEN whitePen = CreatePen(PS_SOLID, 0, kSplashWhite);
  oldBrush = SelectObject(hdc, white);
  oldPen = SelectObject(hdc, whitePen);
  Polygon(hdc, cap, 4);

  // Cap tassel: a short cord from the front edge with a small knot.
  const int knotR = static_cast<int>(2.5 * f);
  const int tasselLen = static_cast<int>(14 * f);
  const int tasselX = cx + dx - static_cast<int>(6 * f);
  const int tasselTop = centerCy + botDy + 1;
  HPEN tasselPen =
      CreatePen(PS_SOLID, static_cast<int>(f < 1.0 ? 1 : 2), kSplashWhite);
  HGDIOBJ prevPen = SelectObject(hdc, tasselPen);
  MoveToEx(hdc, tasselX, tasselTop, nullptr);
  LineTo(hdc, tasselX, tasselTop + tasselLen);
  SelectObject(hdc, prevPen);
  DeleteObject(tasselPen);
  Ellipse(hdc, tasselX - knotR, tasselTop + tasselLen - knotR,
          tasselX + knotR, tasselTop + tasselLen + knotR);
  SelectObject(hdc, oldPen);
  SelectObject(hdc, oldBrush);
  DeleteObject(whitePen);
  DeleteObject(white);

  // App name.
  HFONT titleFont = CreateFontW(
      static_cast<int>(40 * f), 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
      CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
  if (titleFont != nullptr) {
    SetBkMode(hdc, TRANSPARENT);
    SetTextColor(hdc, kSplashWhite);
    HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, titleFont));
    RECT titleRect = {0, centerCy + static_cast<int>(134 * f), width,
                      centerCy + static_cast<int>(186 * f)};
    DrawTextW(hdc, L"StudentHub", -1, &titleRect,
              DT_CENTER | DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    SelectObject(hdc, oldFont);
    DeleteObject(titleFont);
  }

  // Tagline.
  HFONT subFont = CreateFontW(
      static_cast<int>(14 * f), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
      CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
  if (subFont != nullptr) {
    SetTextColor(hdc, kSplashGrey);
    HFONT old = static_cast<HFONT>(SelectObject(hdc, subFont));
    RECT subRect = {0, centerCy + static_cast<int>(196 * f), width,
                    centerCy + static_cast<int>(242 * f)};
    DrawTextW(hdc, L"Next-Gen Digital Campus", -1, &subRect,
              DT_CENTER | DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    SelectObject(hdc, old);
    DeleteObject(subFont);
  }

  EndPaint(window, &ps);
}
