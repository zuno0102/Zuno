// Draws a help or legal page from the same Markdown file the app shows (assets/legal/*.md), with
// the owner's details filled in from assets/legal/legal.json. One copy of the words: the app and
// this public page (the address given to the Play Store) can never say different things.
// Same small Markdown subset as lib/shared/legal/legal_document.dart.
(function () {
  var page = document.body.getAttribute('data-doc');
  var base = 'assets/assets/legal/';
  var out = document.getElementById('doc');

  function esc(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function inline(s) {
    return esc(s).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  }

  function fill(text, fields) {
    return text.replace(/\{\{(\w+)\}\}/g, function (_, name) {
      var v = (fields[name] || '').trim();
      return v || '(to be added)';
    });
  }

  function render(md) {
    var html = [];
    var para = [];
    var list = false;
    function endPara() {
      if (para.length) html.push('<p>' + inline(para.join(' ')) + '</p>');
      para = [];
    }
    function endList() {
      if (list) html.push('</ul>');
      list = false;
    }
    md.split(/\r?\n/).forEach(function (raw) {
      var line = raw.trim();
      var h = /^(#{1,3})\s+(.*)$/.exec(line);
      if (!line) {
        endPara();
        endList();
      } else if (h) {
        endPara();
        endList();
        if (h[1].length === 1) document.title = h[2] + ' · Zuno';
        html.push('<h' + h[1].length + '>' + inline(h[2]) + '</h' + h[1].length + '>');
      } else if (line.indexOf('- ') === 0) {
        endPara();
        if (!list) html.push('<ul>');
        list = true;
        html.push('<li>' + inline(line.slice(2)) + '</li>');
      } else {
        endList();
        para.push(line);
      }
    });
    endPara();
    endList();
    return html.join('\n');
  }

  Promise.all([
    fetch(base + page, { cache: 'no-cache' }).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.text();
    }),
    fetch(base + 'legal.json', { cache: 'no-cache' }).then(function (r) {
      return r.json();
    }),
  ])
    .then(function (res) {
      out.innerHTML = render(fill(res[0], res[1]));
    })
    .catch(function () {
      out.innerHTML = '<p>This page could not be loaded. Please try again.</p>';
    });
})();
