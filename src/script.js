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

  /* plan buttons pre-fill the health-check form */
  var flag = document.getElementById('plan-flag');
  var field = document.getElementById('plan-field');
  Array.prototype.slice.call(document.querySelectorAll('[data-plan]')).forEach(function (btn) {
    btn.addEventListener('click', function () {
      var plan = btn.getAttribute('data-plan');
      if (field) field.value = plan;
      if (flag) { flag.querySelector('span').textContent = 'Asking about: ' + plan; flag.classList.add('show'); }
    });
  });

  /* form guard: explain instead of failing while the endpoint is unconfigured */
  var form = document.getElementById('health-form');
  var msg = document.getElementById('form-msg');
  if (form) {
    form.addEventListener('submit', function (e) {
      if (form.action.indexOf('YOUR-FORM-ID') !== -1) {
        e.preventDefault();
        if (msg) {
          msg.textContent = 'This form isn’t connected yet. Open the HTML file and follow the “WIRE THE FORM” note at the top — it takes about two minutes with any form service.';
          msg.classList.add('show');
        }
      }
    });
  }
})();
