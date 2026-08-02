(function () {
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* scroll-triggered reveals */
  var revealEls = Array.prototype.slice.call(document.querySelectorAll('.reveal'));
  if (reduce || !('IntersectionObserver' in window)) {
    revealEls.forEach(function (el) { el.classList.add('in'); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { entry.target.classList.add('in'); io.unobserve(entry.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });
    revealEls.forEach(function (el) { io.observe(el); });
  }

  /* monitor card: "next check" countdown */
  var count = document.getElementById('mon-count');
  var bar = document.getElementById('mon-bar');
  if (count && bar && !reduce) {
    var total = 299, left = 185;
    setInterval(function () {
      left = left <= 0 ? total : left - 1;
      count.textContent = Math.floor(left / 60) + ':' + ('0' + (left % 60)).slice(-2);
      bar.style.width = (100 * (1 - left / total)).toFixed(1) + '%';
    }, 1000);
  }

  /* FAQ: keep one item open at a time */
  var faqs = Array.prototype.slice.call(document.querySelectorAll('.faq-item'));
  faqs.forEach(function (item) {
    item.addEventListener('toggle', function () {
      if (item.open) faqs.forEach(function (other) { if (other !== item) other.open = false; });
    });
  });

  /* Plan buttons carry purchase intent -> they scroll to the START form and
     preselect the plan there. The free health check is a separate, lower-commitment
     path reached from the header CTA and the "not sure which plan fits?" block. */
  var startFlag  = document.getElementById('start-flag');
  var startPlan  = document.getElementById('start-plan-field');
  var startSel   = document.getElementById('st-plan');
  var startSubj  = document.getElementById('start-subject');
  var hcFlag     = document.getElementById('plan-flag');
  var hcField    = document.getElementById('plan-field');

  Array.prototype.slice.call(document.querySelectorAll('[data-plan]')).forEach(function (btn) {
    btn.addEventListener('click', function () {
      var plan = btn.getAttribute('data-plan');
      if (startPlan) startPlan.value = plan;
      if (startSubj) startSubj.value = 'PLAN SIGNUP — ' + plan;
      /* mirror the choice into the dropdown when it's one of the listed options */
      if (startSel) {
        var matched = false;
        Array.prototype.slice.call(startSel.options).forEach(function (o) {
          if (o.value === plan) { startSel.value = plan; matched = true; }
        });
        if (!matched) startSel.value = 'Not sure yet';
      }
      if (startFlag) {
        startFlag.querySelector('span').textContent = 'Starting with: ' + plan;
        startFlag.classList.add('show');
      }
      /* keep the health-check form's own plan field in step if they wander there */
      if (hcField) hcField.value = plan;
      if (hcFlag) { hcFlag.querySelector('span').textContent = 'Asking about: ' + plan; hcFlag.classList.add('show'); }
    });
  });

  /* Changing the dropdown by hand should update the subject line + badge too. */
  if (startSel) {
    startSel.addEventListener('change', function () {
      var v = startSel.value;
      if (startPlan) startPlan.value = v;
      if (startSubj) startSubj.value = 'PLAN SIGNUP — ' + v;
      if (startFlag) {
        startFlag.querySelector('span').textContent = 'Starting with: ' + v;
        startFlag.classList.add('show');
      }
    });
  }

  /* Form guard: explain instead of failing if an endpoint is ever left unconfigured. */
  [['health-form', 'form-msg'], ['start-form', 'start-msg']].forEach(function (pair) {
    var form = document.getElementById(pair[0]);
    var msg  = document.getElementById(pair[1]);
    if (!form) return;
    form.addEventListener('submit', function (e) {
      if (form.action.indexOf('YOUR-FORM-ID') !== -1) {
        e.preventDefault();
        if (msg) {
          msg.textContent = 'This form isn’t connected yet. Open src/markup.html and set the form action to your form provider’s endpoint — it takes about two minutes.';
          msg.classList.add('show');
        }
      }
    });
  });
})();
