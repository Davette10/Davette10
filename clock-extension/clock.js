// Idle clock for the Home Assistant kiosk.
//
// After `idleSeconds` without a touch, key press or mouse movement, a
// full-screen clock fades in over the dashboard. The first tap dismisses it,
// and that tap (plus the click the browser synthesizes from it) is swallowed
// so it can't accidentally toggle whatever is underneath.
(() => {
  'use strict';

  if (window.top !== window || document.querySelector('kiosk-idle-clock')) return;

  const cfg = Object.assign(
    { idleSeconds: 120, use24h: false, showSeconds: false },
    self.HA_KIOSK_CLOCK || {}
  );
  const IDLE_MS = Math.max(5, Number(cfg.idleSeconds) || 120) * 1000;
  const FADE_MS = 500;
  // How long after the finger lifts we keep swallowing input, to catch the
  // synthesized mouse events and click that follow a tap.
  const RELEASE_MS = 400;

  const CSS = `
    .screen {
      position: fixed; inset: 0; overflow: hidden;
      display: grid; place-items: center;
      background: #07080b; color: #f4f5f7;
      font-family: "Inter", "Inter Variable", system-ui, -apple-system, "Segoe UI",
        Roboto, "Helvetica Neue", Arial, sans-serif;
      opacity: 0; transition: opacity ${FADE_MS}ms ease;
      touch-action: none; user-select: none; -webkit-user-select: none;
      -webkit-tap-highlight-color: transparent; cursor: none;
    }
    .screen.on { opacity: 1; }

    .glow {
      position: absolute; inset: -25%;
      background:
        radial-gradient(38% 48% at 28% 32%, rgba(99, 112, 255, 0.20), transparent 70%),
        radial-gradient(42% 52% at 76% 72%, rgba(45, 212, 191, 0.14), transparent 70%);
      animation: glow 40s ease-in-out infinite alternate;
    }
    @keyframes glow {
      from { transform: translate(-4%, -3%) rotate(0deg); }
      to   { transform: translate(4%, 3%) rotate(8deg); }
    }

    .face {
      position: relative;
      display: flex; flex-direction: column; align-items: center;
      transition: transform 3s ease;
    }
    .time {
      display: flex; align-items: flex-start;
      font-size: min(30vw, 56vh); font-weight: 200; line-height: 0.9;
      letter-spacing: -0.04em;
      font-variant-numeric: tabular-nums; font-feature-settings: "tnum" 1;
    }
    .face.with-seconds .time { font-size: min(19vw, 44vh); }
    .ampm {
      margin: 0.32em 0 0 0.3em;
      font-size: 0.15em; font-weight: 500; letter-spacing: 0.12em;
      color: rgba(244, 245, 247, 0.55);
    }
    .ampm:empty { display: none; }

    .bar {
      width: 36%; height: 3px; margin-top: 4vh;
      border-radius: 3px; overflow: hidden;
      background: rgba(255, 255, 255, 0.08);
    }
    .bar i {
      display: block; height: 100%; transform-origin: left center;
      background: linear-gradient(90deg, #6370ff, #2dd4bf);
      animation: sweep 60s linear infinite;
    }
    @keyframes sweep {
      from { transform: scaleX(0); }
      to   { transform: scaleX(1); }
    }

    .date {
      margin-top: 3.5vh;
      font-size: min(3.6vw, 6.5vh); font-weight: 400;
      letter-spacing: 0.2em; text-transform: uppercase;
      color: rgba(244, 245, 247, 0.62);
    }

    .hint {
      position: absolute; bottom: 5vh;
      font-size: min(2.4vw, 4.2vh); letter-spacing: 0.08em;
      color: rgba(244, 245, 247, 0.4);
      opacity: 0;
    }
    .screen.on .hint { animation: hint 5s ease forwards; }
    @keyframes hint {
      0% { opacity: 0; } 15% { opacity: 1; } 70% { opacity: 1; } 100% { opacity: 0; }
    }
  `;

  const host = document.createElement('kiosk-idle-clock');
  host.style.cssText =
    'position:fixed;inset:0;z-index:2147483647;display:none;margin:0;padding:0;border:0;';
  const root = host.attachShadow({ mode: 'closed' });
  root.innerHTML = `
    <style>${CSS}</style>
    <div class="screen">
      <div class="glow"></div>
      <div class="face">
        <div class="time"><span class="hm"></span><span class="ampm"></span></div>
        <div class="bar"><i></i></div>
        <div class="date"></div>
      </div>
      <div class="hint">Tap anywhere to return</div>
    </div>`;
  document.documentElement.appendChild(host);

  const screen = root.querySelector('.screen');
  const face = root.querySelector('.face');
  const hmEl = root.querySelector('.hm');
  const ampmEl = root.querySelector('.ampm');
  const dateEl = root.querySelector('.date');
  const barEl = root.querySelector('.bar i');
  if (cfg.showSeconds) face.classList.add('with-seconds');

  const pad = (n) => String(n).padStart(2, '0');
  const dateFmt = new Intl.DateTimeFormat(undefined, {
    weekday: 'long', day: 'numeric', month: 'long',
  });

  let lastMinute = -1;
  function render() {
    const now = new Date();
    const h = now.getHours();
    const hour = cfg.use24h ? pad(h) : String(h % 12 || 12);
    let text = `${hour}:${pad(now.getMinutes())}`;
    if (cfg.showSeconds) text += `:${pad(now.getSeconds())}`;
    if (hmEl.textContent !== text) hmEl.textContent = text;
    ampmEl.textContent = cfg.use24h ? '' : h < 12 ? 'AM' : 'PM';

    const minute = Math.floor(now.getTime() / 60000);
    if (minute !== lastMinute) {
      lastMinute = minute;
      dateEl.textContent = dateFmt.format(now);
      // Nudge the clock a little each minute so nothing sits on the same
      // pixels all day.
      const dx = (Math.random() * 2 - 1) * 3;
      const dy = (Math.random() * 2 - 1) * 3;
      face.style.transform = `translate(${dx.toFixed(2)}vw, ${dy.toFixed(2)}vh)`;
    }
  }

  function syncSecondsBar() {
    barEl.style.animation = 'none';
    void barEl.offsetWidth; // restart the animation
    barEl.style.animation = '';
    barEl.style.animationDelay = `-${(Date.now() % 60000) / 1000}s`;
  }

  // --- Input blocking while the clock is up (and briefly after) ------------

  const BLOCKED = [
    'pointerdown', 'pointerup', 'pointercancel', 'pointermove',
    'touchstart', 'touchend', 'touchcancel', 'touchmove',
    'mousedown', 'mouseup', 'click', 'dblclick', 'contextmenu',
    'wheel', 'keydown', 'keyup',
  ];
  const PRESS = new Set(['pointerdown', 'touchstart', 'mousedown']);
  const LIFT = new Set([
    'pointerup', 'pointercancel', 'touchend', 'touchcancel', 'mouseup', 'click',
  ]);

  let showing = false;
  let blocking = false;
  let pressed = false;
  let releaseTimer = 0;
  let hideTimer = 0;
  let lastActivity = Date.now();

  function swallow(e) {
    if (e.cancelable) e.preventDefault();
    e.stopImmediatePropagation();
  }

  function onBlockedInput(e) {
    swallow(e);
    if (PRESS.has(e.type)) pressed = true;
    if (LIFT.has(e.type)) pressed = false;
    if (showing && (PRESS.has(e.type) || e.type === 'keydown' || e.type === 'wheel')) {
      hide();
    }
    if (!showing && !pressed) scheduleRelease();
  }

  function startBlocking() {
    clearTimeout(releaseTimer);
    if (blocking) return;
    blocking = true;
    for (const t of BLOCKED) {
      window.addEventListener(t, onBlockedInput, { capture: true, passive: false });
    }
  }

  function scheduleRelease() {
    clearTimeout(releaseTimer);
    releaseTimer = setTimeout(() => {
      if (showing || pressed) return;
      blocking = false;
      for (const t of BLOCKED) {
        window.removeEventListener(t, onBlockedInput, { capture: true });
      }
      lastActivity = Date.now();
    }, RELEASE_MS);
  }

  // --- Show / hide ----------------------------------------------------------

  function show() {
    if (showing) return;
    showing = true;
    pressed = false;
    clearTimeout(hideTimer);
    startBlocking();
    lastMinute = -1;
    render();
    host.style.display = 'block';
    syncSecondsBar();
    void screen.offsetWidth; // let the fade-in transition run
    screen.classList.add('on');
  }

  function hide() {
    if (!showing) return;
    showing = false;
    lastActivity = Date.now();
    screen.classList.remove('on');
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
      if (!showing) host.style.display = 'none';
    }, FADE_MS);
  }

  // --- Idle tracking --------------------------------------------------------

  const markActive = () => { lastActivity = Date.now(); };
  for (const t of ['pointerdown', 'pointermove', 'touchstart', 'keydown', 'wheel']) {
    window.addEventListener(t, markActive, { capture: true, passive: true });
  }

  setInterval(() => {
    const idleFor = Date.now() - lastActivity;
    if (showing) {
      render();
    } else if (!blocking && idleFor >= IDLE_MS) {
      show();
    } else if (blocking && idleFor > 5000) {
      // Safety net: never leave the dashboard unresponsive if a "finger up"
      // event went missing.
      pressed = false;
      scheduleRelease();
    }
  }, 1000);

  // Handy for testing from DevTools: window.dispatchEvent(new Event('kiosk-clock:show'))
  window.addEventListener('kiosk-clock:show', show);
})();
