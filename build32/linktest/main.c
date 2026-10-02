/* Link test: a program using EGL with GLES 2/3, desktop GL or GLES 1 on the
 * Switch's default window. Built three ways by run.sh; not run. */
#include <switch.h>
#include <EGL/egl.h>
#if defined(TEST_GL)
#include <GL/gl.h>
#elif defined(TEST_GLES1)
#include <GLES/gl.h>
#else
#include <GLES3/gl3.h>
#endif

int main(void) {
  EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  eglInitialize(d, NULL, NULL);
#if defined(TEST_GL)
  eglBindAPI(EGL_OPENGL_API);
#else
  eglBindAPI(EGL_OPENGL_ES_API);
#endif
  EGLConfig cfg;
  EGLint n = 0;
  eglChooseConfig(d, (const EGLint[]){EGL_NONE}, &cfg, 1, &n);
  EGLSurface s = eglCreateWindowSurface(d, cfg, (EGLNativeWindowType)nwindowGetDefault(), NULL);
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, NULL);
  eglMakeCurrent(d, s, s, c);
  glClearColor(0.2f, 0.4f, 0.6f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
#if !defined(TEST_GL) && !defined(TEST_GLES1)
  GLuint sh = glCreateShader(GL_VERTEX_SHADER);
  glDeleteShader(sh);
#endif
  eglSwapBuffers(d, s);
  eglTerminate(d);
  return 0;
}
