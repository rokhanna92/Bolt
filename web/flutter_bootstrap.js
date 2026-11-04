{{flutter_js}}
{{flutter_build_config}}

// Flutter keeps its fast WebAssembly engine off for Safari by default, but
// iPhones are who this build is for, so it is on. If it fails on a phone, Bolt
// goes back to the JavaScript engine rather than showing a blank screen, and
// tries again after the next Flutter upgrade.
(() => {
  const KEY = 'bolt-js-engine';
  const revision = _flutter.buildConfig.engineRevision;
  const read = () => { try { return localStorage.getItem(KEY); } catch (_) { return null; } };
  const safari = navigator.vendor.includes('Apple');
  const useWasm = safari && read() !== revision;

  const fallBack = () => {
    try { localStorage.setItem(KEY, revision); } catch (_) { return; }
    location.reload();
  };

  if (useWasm) {
    let started = false;
    window.addEventListener('flutter-first-frame', () => { started = true; });
    setTimeout(() => { if (!started) fallBack(); }, 45000);
    window.addEventListener('error', (e) => {
      if (e.error instanceof WebAssembly.RuntimeError) fallBack();
    });
  }

  const load = _flutter.loader.load({ config: { wasmAllowList: { webkit: useWasm } } });
  if (useWasm) load.catch(fallBack);
})();
