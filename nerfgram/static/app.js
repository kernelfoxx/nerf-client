(() => {
  const S = {
    auth: new URLSearchParams(location.search).get('auth') || localStorage.getItem('nerfgram_auth') || '',
    config: null, plan: null, method: 'stars', network: null, status: null
  };
  if (S.auth) localStorage.setItem('nerfgram_auth', S.auth);
  const $ = (id) => document.getElementById(id);
  const toast = (msg) => {
    $('toast').textContent = msg; $('toast').classList.add('show');
    setTimeout(() => $('toast').classList.remove('show'), 3200);
  };
  const post = async (path, body) => {
    const r = await fetch(path, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({auth:S.auth, ...body})});
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.detail || 'Ошибка сервера');
    return data;
  };
  const step = (n) => {
    document.querySelectorAll('.step').forEach(el => {
      const i = +el.dataset.step;
      el.classList.toggle('active', i === n);
      el.classList.toggle('done', i < n);
    });
  };

  async function load() {
    try {
      S.config = await (await fetch('/api/config')).json();
      if (S.auth) {
        S.status = await (await fetch('/api/status?auth=' + encodeURIComponent(S.auth))).json();
        const pill = $('statusPill');
        pill.classList.add('ok');
        pill.lastElementChild.textContent = S.status.active ? 'подписка активна' : 'авторизован';
        $('trialNote').hidden = !S.status.trial_used;
      } else {
        $('statusPill').lastElementChild.textContent = 'открой бота для входа';
      }
      const week = S.config.plans.find(p => p.id === 'week');
      const month = S.config.plans.find(p => p.id === 'month');
      document.querySelector('[data-plan="week"] .price small').textContent = `или ${week.stars} Stars`;
      document.querySelector('[data-plan="month"] .price small').textContent = `или ${month.stars} Stars`;
    } catch (e) { toast(e.message); }
  }

  async function choosePlan(id) {
    if (!S.auth) { toast('Сначала открой бота и нажми «Открыть Nerf Gram»'); return; }
    if (id === 'trial') {
      try {
        const data = await post('/api/trial', {});
        $('doneText').textContent = data.message;
        $('plansSection').classList.add('hidden'); $('paySection').classList.add('hidden');
        $('doneSection').classList.remove('hidden'); step(3);
      } catch (e) { toast(e.message); }
      return;
    }
    S.plan = S.config.plans.find(p => p.id === id);
    if (!S.plan) return;
    document.querySelectorAll('.plan').forEach(el => el.classList.toggle('selected', el.dataset.plan === id));
    $('selectedPlanLabel').textContent = `${S.plan.label} · $${S.plan.usd}`;
    $('starsAmount').textContent = `${S.plan.stars} XTR`;
    $('plansSection').classList.add('hidden');
    $('paySection').classList.remove('hidden');
    step(2);
    renderNetworks();
    window.scrollTo({top:0, behavior:'smooth'});
  }

  function renderNetworks() {
    const wrap = $('networks'); wrap.innerHTML = '';
    if (!S.plan.wallets.length) {
      wrap.innerHTML = '<p style="font-size:12px;color:#9aa3bd">Крипто-оплата не настроена. Используй Telegram Stars.</p>';
      return;
    }
    S.plan.wallets.forEach(w => {
      const b = document.createElement('button');
      b.className = 'network'; b.dataset.network = w.network;
      b.innerHTML = `<b>${w.label}</b><small>≈ ${w.amount} ${w.ticker}</small>`;
      b.onclick = () => {
        S.network = w;
        wrap.querySelectorAll('.network').forEach(x => x.classList.toggle('active', x === b));
        $('addressCard').hidden = false;
        $('networkLabel').textContent = w.label;
        $('amountLabel').textContent = `${w.amount} ${w.ticker}`;
        $('addressValue').textContent = w.address;
      };
      wrap.appendChild(b);
    });
  }

  function setMethod(m) {
    S.method = m;
    document.querySelectorAll('.method').forEach(el => el.classList.toggle('active', el.dataset.method === m));
    $('starsPanel').classList.toggle('hidden', m !== 'stars');
    $('cryptoPanel').classList.toggle('hidden', m !== 'crypto');
  }

  async function payStars() {
    if (!S.plan) return;
    const btn = $('payStars'); btn.disabled = true;
    try {
      const data = await post('/api/stars/invoice', {plan:S.plan.id});
      if (window.Telegram && Telegram.WebApp && Telegram.WebApp.openInvoice) {
        Telegram.WebApp.openInvoice(data.url, (status) => {
          if (status === 'paid') { $('doneText').textContent = 'Оплата принята! Бот пришлёт ключ через несколько секунд.'; finish(); }
          else if (status === 'failed') toast('Оплата не прошла');
        });
      } else {
        location.href = data.url;
      }
    } catch (e) { toast(e.message); }
    finally { btn.disabled = false; }
  }

  async function submitCrypto() {
    if (!S.network) { toast('Выбери сеть'); return; }
    const hash = $('txHash').value.trim();
    if (hash.length < 10) { toast('Вставь хеш транзакции'); return; }
    const btn = $('submitCrypto'); btn.disabled = true;
    try {
      const data = await post('/api/crypto/claim', {plan:S.plan.id, network:S.network.network, tx_hash:hash});
      $('doneText').textContent = data.message;
      finish();
    } catch (e) { toast(e.message); }
    finally { btn.disabled = false; }
  }

  function finish() {
    $('paySection').classList.add('hidden'); $('plansSection').classList.add('hidden');
    $('doneSection').classList.remove('hidden'); step(3);
    $('backBot').href = `https://t.me/${S.config.bot_username}`;
  }

  document.querySelectorAll('.plan-btn').forEach(b => b.onclick = () => choosePlan(b.dataset.plan));
  document.querySelectorAll('.method').forEach(b => b.onclick = () => setMethod(b.dataset.method));
  $('payStars').onclick = payStars;
  $('submitCrypto').onclick = submitCrypto;
  $('copyAddress').onclick = async () => {
    try { await navigator.clipboard.writeText($('addressValue').textContent); toast('Адрес скопирован'); }
    catch (e) { toast('Выдели адрес вручную'); }
  };
  if (window.Telegram && Telegram.WebApp) { Telegram.WebApp.ready(); Telegram.WebApp.expand(); }
  load();
})();
