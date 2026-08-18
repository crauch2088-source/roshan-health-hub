export function renderErrorPage(): string {
  return `<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8" />
    <title>حدث خطأ غير متوقع</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body { font-family: system-ui, sans-serif; background: #f8fafc; color: #1e293b; display: grid; place-items: center; min-height: 100vh; margin: 0; padding: 1.5rem; }
      .card { max-width: 28rem; width: 100%; text-align: center; padding: 2rem; background: white; border-radius: 1rem; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); }
      h1 { font-size: 1.5rem; margin: 0 0 0.5rem; color: #0866FF; } /* استخدام اللون المفضل #0866FF */
      p { color: #64748b; margin: 0 0 1.5rem; }
      .actions { display: flex; gap: 0.5rem; justify-content: center; }
      button { padding: 0.6rem 1.2rem; border-radius: 0.5rem; font-weight: 600; cursor: pointer; border: none; }
      .primary { background: #0866FF; color: #fff; }
      .secondary { background: #f1f5f9; color: #1e293b; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>عذراً، حدث خلل فني</h1>
      <p>نعتذر عن هذا الإزعاج. يرجى محاولة تحديث الصفحة أو العودة للرئيسية.</p>
      <div class="actions">
        <button class="primary" onclick="location.reload()">تحديث الصفحة</button>
        <a class="secondary" href="/" style="text-decoration:none; padding: 0.6rem 1.2rem; border-radius: 0.5rem; color: inherit;">العودة للرئيسية</a>
      </div>
    </div>
  </body>
</html>`;
}
