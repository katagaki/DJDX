// swiftlint:disable file_length

let globalJSFunctions = """
function waitForElementToExist(selector) {
    return new Promise(resolve => {
        if (document.querySelector(selector)) {
            return resolve(document.querySelector(selector))
        }
        const observer = new MutationObserver(mutations => {
            if (document.querySelector(selector)) {
                observer.disconnect()
                resolve(document.querySelector(selector))
            }
        })
        observer.observe(document.body, {
            childList: true,
            subtree: true
        })
    })
}

var head = document.head || document.getElementsByTagName('head')[0]
var style = document.createElement('style')
style.type = 'text/css'
"""

let globalCleanup = """
// テキスト選択を無効化
var disableSelectionCSS = '*{-webkit-touch-callout:none;-webkit-user-select:none}'
style.appendChild(document.createTextNode(disableSelectionCSS))
head.appendChild(style)

// メニューバーを取り除く
waitForElementToExist('#id_nav_menu_1')
    .then((element) => {
    document.getElementById('id_nav_menu_1').remove()
})
waitForElementToExist('#menu-sp')
    .then((element) => {
    document.getElementById('menu-sp').remove()
})
waitForElementToExist('#menu-pc')
    .then((element) => {
    document.getElementById('menu-pc').remove()
})

// ユーザーバーを取り除く
waitForElementToExist('#log-on')
    .then((element) => {
    document.getElementById('log-on').remove()
})

// タイトルバーを取り除く
waitForElementToExist('#page-title')
    .then((element) => {
    document.getElementById('page-title').remove()
})

// TOPに戻るを取り除く
waitForElementToExist('#page-top')
    .then((element) => {
    document.getElementById('#page-top').remove()
})

// フッターを取り除く
document.body.style.setProperty('margin-bottom', '0', 'important')
waitForElementToExist('footer').then((element) => {
    document.getElementsByTagName('footer')[0].remove()
})
waitForElementToExist('#synalio-iframe').then((element) => {
    document.getElementById('synalio-iframe').remove()
})

// Cookieバナーを取り除く
waitForElementToExist('#onetrust-consent-sdk').then((element) => {
    document.getElementById('onetrust-consent-sdk').remove()
})

// TOPに戻るを取り除く
waitForElementToExist('#page-top').then((element) => {
    document.getElementById('page-top').remove()
})
"""

let loginPageDarkModeUserScript = """
(function() {
    var darkModeCSS = `
@media (prefers-color-scheme: dark) {
    html, body,
    main,
    [class*="Layout"],
    #id_ea_common_content_whole, #base, #base-inner {
        background-color: #000000 !important;
        color: #ffffff !important;
    }
    header,
    footer,
    [class*="Header"],
    [class*="Footer"] {
        background-color: #000000 !important;
        color: #ffffff !important;
    }
    [class*="login__"],
    .card,
    .accordion-item,
    .accordion-button,
    body .bg-light,
    body .bg-white,
    #email-form {
        border-color: #46464a !important;
        background-color: #1c1c1e !important;
        color: #ffffff !important;
    }
    h1, h2, h3, h4, h5, h6,
    p, span, summary, label,
    .nav-link {
        color: #ffffff !important;
    }
    .form-floating > label {
        color: #aaaaaa !important;
    }
    .form-floating > .form-control:focus ~ label {
        color: #eeeeee !important;
    }
    .m-icon--arrow_back_back {
        filter: invert();
        opacity: 40%;
    }
    input,
    textarea,
    select,
    .form-control,
    .form-control:focus {
        background-color: #000000 !important;
        color: #ffffff !important;
        border-color: #46464a !important;
    }
    a, .link-primary {
        color: #4da3ff !important;
    }
}

@media (prefers-color-scheme: light) {
    body {
        background-color: #ffffff;
        color: #000000;
    }
}
`;
    var style = document.createElement('style');
    style.type = 'text/css';
    style.textContent = darkModeCSS;
    (document.head || document.documentElement).appendChild(style);
})();
"""

let loginPageCleanup = """
// チャットポップアップを取り除く
waitForElementToExist('.fs-6').then((element) => {
    document.getElementsByClassName('fs-6')[0].remove()
})
"""

let otpAutofillUserScript = """
(function() {
    function isOtpBox(el) {
        if (!el || el.tagName !== 'INPUT') { return false; }
        if (el.hasAttribute('data-djdx-otp')) { return true; }
        var type = (el.getAttribute('type') || 'text').toLowerCase();
        if (type !== 'text' && type !== 'tel' && type !== 'number') { return false; }
        var autocomplete = (el.getAttribute('autocomplete') || '').toLowerCase();
        if (autocomplete.indexOf('one-time-code') !== -1) { return true; }
        var maxLength = el.getAttribute('maxlength');
        var inputmode = (el.getAttribute('inputmode') || '').toLowerCase();
        var pattern = el.getAttribute('pattern') || '';
        var numericish = inputmode === 'numeric' || inputmode === 'tel'
            || pattern.indexOf('0-9') !== -1 || type === 'tel' || type === 'number';
        return maxLength === '1' && numericish;
    }

    function otpBoxes(target) {
        var scope = target.form || target.closest('form') || document;
        var boxes = Array.prototype.slice.call(scope.querySelectorAll('input')).filter(isOtpBox);
        if (boxes.indexOf(target) === -1 && isOtpBox(target)) { boxes.push(target); }
        return boxes;
    }

    function setValue(el, value) {
        var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        setter.call(el, value);
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function distribute(boxes, startIndex, data) {
        var chars = (data || '').replace(/\\s/g, '').split('');
        var count = 0;
        for (var i = 0; i < chars.length && (startIndex + i) < boxes.length; i++) {
            setValue(boxes[startIndex + i], chars[i]);
            count++;
        }
        var lastIndex = startIndex + count - 1;
        if (lastIndex >= 0 && boxes[lastIndex]) { boxes[lastIndex].focus(); }
    }

    function indexOfTarget(boxes, target) {
        var index = boxes.indexOf(target);
        return index === -1 ? 0 : index;
    }

    document.addEventListener('focusin', function(event) {
        var target = event.target;
        if (!isOtpBox(target)) { return; }
        otpBoxes(target).forEach(function(box) {
            box.setAttribute('data-djdx-otp', '');
            box.removeAttribute('maxlength');
        });
    }, true);

    function fill(target, data) {
        var paste = new Event('paste', { bubbles: true, cancelable: true });
        Object.defineProperty(paste, 'clipboardData', {
            value: { getData: function() { return data; } }
        });
        target.dispatchEvent(paste);
        if (!paste.defaultPrevented) {
            var boxes = otpBoxes(target);
            distribute(boxes, indexOfTarget(boxes, target), data);
        }
    }

    document.addEventListener('beforeinput', function(event) {
        var target = event.target;
        if (!isOtpBox(target)) { return; }
        var data = event.data || (event.dataTransfer ? event.dataTransfer.getData('text/plain') : '');
        if (data && data.length > 1) {
            event.preventDefault();
            event.stopImmediatePropagation();
            fill(target, data);
        }
    }, true);

    document.addEventListener('input', function(event) {
        var target = event.target;
        if (!isOtpBox(target)) { return; }
        var data = target.value || '';
        if (data.length > 1 && data.length >= otpBoxes(target).length) {
            event.stopImmediatePropagation();
            fill(target, data);
        }
    }, true);
})();
"""

let scoreDownloadFetchBody = """
async function fetchScoreData() {
    const buttons = Array.from(document.getElementsByClassName('submit_btn'));
    const button = buttons.find(function(candidate) { return candidate.value === buttonValue; });
    if (!button) { return 'ERR:maintenance'; }
    const form = button.form || button.closest('form');
    if (!form) { return 'ERR:maintenance'; }

    const params = new URLSearchParams();
    Array.from(form.elements).forEach(function(element) {
        if (!element.name) { return; }
        const type = (element.type || '').toLowerCase();
        if (type === 'submit' || type === 'button' || type === 'reset' || type === 'file') { return; }
        if ((type === 'checkbox' || type === 'radio') && !element.checked) { return; }
        params.append(element.name, element.value);
    });
    if (button.name) { params.append(button.name, button.value); }

    const action = form.getAttribute('action');
    const targetURL = action ? new URL(action, document.baseURI).href : location.href;
    const method = (form.getAttribute('method') || 'POST').toUpperCase();

    let response;
    if (method === 'GET') {
        const joiner = targetURL.indexOf('?') === -1 ? '?' : '&';
        response = await fetch(targetURL + joiner + params.toString(), {
            method: 'GET',
            credentials: 'same-origin'
        });
    } else {
        response = await fetch(targetURL, {
            method: 'POST',
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params.toString()
        });
    }

    const finalURL = response.url || '';
    if (finalURL.indexOf('/error/error.html') !== -1) {
        const match = finalURL.match(/[?&]err=([0-9]+)/);
        return 'ERR:' + (match ? match[1] : 'server');
    }

    const html = await response.text();
    const parsed = new DOMParser().parseFromString(html, 'text/html');
    const node = parsed.getElementById('score_data');
    if (node) {
        const value = (node.value !== undefined && node.value !== null && node.value !== '')
            ? node.value
            : (node.getAttribute('value') || node.textContent || '');
        if (value && value.length > 0) { return value; }
    }
    if (html.indexOf('/error/error.html') !== -1) { return 'ERR:server'; }
    return 'ERR:empty';
}

for (let attempt = 0; attempt < 3; attempt++) {
    try {
        return await fetchScoreData();
    } catch (error) {
        if (attempt === 2) { return 'ERR:network'; }
        await new Promise(function(resolve) { setTimeout(resolve, 600 * (attempt + 1)); });
    }
}
return 'ERR:network';
"""

let sdvxScoreDownloadFetchBody = """
async function fetchSDVXScoreData() {
    let csv = document.getElementById('score_data').value;
    if (csv.indexOf('楽曲名') !== -1) { return csv; }
    return 'ERR:empty';
}

return await fetchSDVXScoreData();
"""

let polarisChordScoreDataFetchBody = """
async function fetchPolarisChordScoreData() {
    const endpoint = new URL('../json/pdata_getdata.html', location.href).href;
    const body = new URLSearchParams({ service_kind: 'music_data', pdata_kind: 'music_data' });
    const response = await fetch(endpoint, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString()
    });

    const finalURL = response.url || '';
    if (finalURL.indexOf('/error/error.html') !== -1) {
        const match = finalURL.match(/[?&]err=([0-9]+)/);
        return 'ERR:' + (match ? match[1] : 'server');
    }

    const json = JSON.parse(await response.text());
    const highscore = json && json.data && json.data.score_data
        && json.data.score_data.usr_music_highscore;
    let music = highscore && highscore.music;
    if (!music) { return 'ERR:empty'; }
    if (!Array.isArray(music)) { music = [music]; }

    const rows = [];
    music.forEach(function(entry) {
        const chartList = entry.chart_list && entry.chart_list.chart;
        if (!chartList) { return; }
        const charts = Array.isArray(chartList) ? chartList : [chartList];
        charts.forEach(function(chart) {
            rows.push({
                musicID: String(entry.music_id || ''),
                title: entry.name || '',
                category: String(entry.genre || ''),
                difficulty: chart.chart_difficulty_type,
                level: String(chart.difficult_disp || ''),
                rate: chart.achievement_rate,
                score: chart.highscore,
                clearStatus: chart.clear_status
            });
        });
    });

    if (rows.length === 0) { return 'ERR:empty'; }
    return JSON.stringify(rows);
}

for (let attempt = 0; attempt < 3; attempt++) {
    try {
        return await fetchPolarisChordScoreData();
    } catch (error) {
        if (attempt === 2) { return 'ERR:network'; }
        await new Promise(function(resolve) { setTimeout(resolve, 600 * (attempt + 1)); });
    }
}
return 'ERR:network';
"""

let ddrScoreDataFetchBody = """
async function fetchDDRScoreData() {
    const styles = [{ key: 'SINGLE', page: 'music_data_single.html' },
                    { key: 'DOUBLE', page: 'music_data_double.html' }];
    const diffNames = ['BEGINNER', 'BASIC', 'DIFFICULT', 'EXPERT', 'CHALLENGE'];
    const rows = [];

    function pageURL(page, offset) {
        const u = new URL(page, location.href);
        u.search = 'offset=' + offset + '&filter=0&display=score';
        return u.href;
    }

    function imgStem(el) {
        if (!el) { return ''; }
        const img = el.querySelector('img');
        if (!img) { return ''; }
        const file = (img.getAttribute('src') || '').split('/').pop() || '';
        return file.split('.')[0];
    }

    let pagesFetched = 0;
    for (const style of styles) {
        const seen = new Set();
        for (let offset = 0; offset < 80; offset++) {
            const response = await fetch(pageURL(style.page, offset),
                                         { method: 'GET', credentials: 'same-origin' });
            const finalURL = response.url || '';
            if (finalURL.indexOf('/error/') !== -1 || finalURL.indexOf('login.html') !== -1) {
                const match = finalURL.match(/[?&]err=([0-9]+)/);
                return 'ERR:' + (match ? match[1] : 'server');
            }
            const html = await response.text();
            const doc = new DOMParser().parseFromString(html, 'text/html');
            const cards = Array.prototype.slice.call(doc.querySelectorAll('.music-card'));
            pagesFetched++;
            if (window.webkit && window.webkit.messageHandlers
                && window.webkit.messageHandlers.ddrProgress) {
                window.webkit.messageHandlers.ddrProgress.postMessage({ pages: pagesFetched });
            }
            if (cards.length === 0) { break; }

            let newCount = 0;
            for (const card of cards) {
                const header = card.querySelector('.chart a.music_info');
                if (!header) { continue; }
                const indexMatch = (header.getAttribute('href') || '').match(/index=([^&]+)/);
                const songIndex = indexMatch ? indexMatch[1] : '';
                if (!songIndex || seen.has(songIndex)) { continue; }
                seen.add(songIndex);
                newCount++;

                const nameEl = card.querySelector('.music-name');
                const title = nameEl ? nameEl.textContent.trim() : '';
                const jacketEl = card.querySelector('img.left-image');
                const jacket = jacketEl ? (jacketEl.getAttribute('src') || '') : '';

                diffNames.forEach(function(diff) {
                    const cell = card.querySelector('.rank.' + diff + ' .data');
                    if (!cell) { return; }
                    const link = cell.querySelector('a[href*="difficulty="]');
                    if (!link) { return; }
                    const scoreEl = cell.querySelector('.data_score');
                    const flareEl = cell.querySelector('.data_flareskill');
                    rows.push({
                        songIndex: songIndex,
                        title: title,
                        jacket: jacket,
                        style: style.key,
                        difficulty: diff,
                        score: scoreEl ? scoreEl.textContent.trim() : '',
                        rank: imgStem(cell.querySelector('.data_rank')),
                        clearKind: imgStem(cell.querySelector('.data_clearkind')),
                        flareSkill: flareEl ? flareEl.textContent.trim() : '',
                        flareRank: imgStem(cell.querySelector('.data_flarerank'))
                    });
                });
            }
            if (newCount === 0) { break; }
        }
    }

    if (rows.length === 0) { return 'ERR:empty'; }
    return JSON.stringify(rows);
}

for (let attempt = 0; attempt < 3; attempt++) {
    try {
        return await fetchDDRScoreData();
    } catch (error) {
        if (attempt === 2) { return 'ERR:network'; }
        await new Promise(function(resolve) { setTimeout(resolve, 800 * (attempt + 1)); });
    }
}
return 'ERR:network';
"""

let popnScoreDataFetchBody = """
async function fetchPopnScoreData(basePath, verAll) {
    const maxLevel = 50;
    const workerCount = 3;

    async function fetchDoc(url) {
        const response = await fetch(url, { method: 'GET', credentials: 'same-origin' });
        const finalURL = response.url || '';
        if (finalURL.indexOf('/error/') !== -1 || finalURL.indexOf('login.html') !== -1) {
            const match = finalURL.match(/[?&]err=([0-9]+)/);
            throw { sentinel: match ? match[1] : 'server' };
        }
        const html = await response.text();
        return new DOMParser().parseFromString(html, 'text/html');
    }

    function text(el) {
        return el ? el.textContent.replace(/\\s+/g, ' ').trim() : '';
    }

    function imageCode(img, pattern) {
        if (!img) { return ''; }
        const match = (img.getAttribute('src') || '').match(pattern);
        return match ? match[1] : '';
    }

    function scoreCell(cell) {
        const imgs = cell.querySelectorAll('img');
        let medal = '';
        let rank = '';
        imgs.forEach(function(img) {
            medal = medal || imageCode(img, /meda_([a-z]+)\\.png/);
            rank = rank || imageCode(img, /rank_([a-z0-9_]+)\\.png/);
        });
        const digits = text(cell).replace(/[^0-9]/g, '');
        return { score: digits ? parseInt(digits, 10) : 0, medal: medal || 'none', rank: rank || 'none' };
    }

    function absoluteURL(img) {
        if (!img) { return ''; }
        try { return new URL(img.getAttribute('src') || '', location.href).href; } catch (e) { return ''; }
    }

    function parseProfile(doc) {
        const profile = { name: '', popnClass: '', popnClassIcon: '' };
        doc.querySelectorAll('div.st_box div.item').forEach(function(item) {
            const value = item.nextElementSibling;
            if (!profile.name && text(item).indexOf('プレーヤー名') !== -1 && value) {
                profile.name = text(value);
            }
        });
        doc.querySelectorAll('div.st_box ul li').forEach(function(li) {
            const label = li.querySelector('p');
            const value = li.querySelector('div');
            if (!profile.name && label && value && text(label).indexOf('プレーヤー名') !== -1) {
                profile.name = text(value);
            }
        });
        const classEl = doc.querySelector('#popnclass');
        if (classEl) {
            const value = parseFloat(text(classEl));
            if (!isNaN(value)) { profile.popnClass = value.toFixed(2); }
            profile.popnClassIcon = absoluteURL(classEl.querySelector('img'));
        }
        return profile;
    }

    function parseLevelPage(doc, level) {
        const rows = [];
        const legacyRows = doc.querySelectorAll('ul.mu_list_table > li');
        if (legacyRows.length > 0) {
            legacyRows.forEach(function(li) {
                const music = li.querySelector('div.col_music_lv');
                const scoreEl = li.querySelector('div.col_ex_lv');
                if (!music || !scoreEl) { return; }
                const link = music.querySelector('a');
                const subDivs = music.querySelectorAll('div');
                const cell = scoreCell(scoreEl);
                rows.push({
                    title: text(link),
                    genre: text(subDivs[0]),
                    artist: text(subDivs[1]),
                    difficulty: text(li.querySelector('div.col_normal_lv')),
                    level: parseInt(text(li.querySelector('div.col_hyper_lv')), 10) || level,
                    score: cell.score, medal: cell.medal, rank: cell.rank
                });
            });
            return rows;
        }
        doc.querySelectorAll('ul.mu_list_lv_table > li').forEach(function(li) {
            if (li.classList.contains('st_th')) { return; }
            const cells = li.children;
            if (cells.length < 4) { return; }
            const link = cells[0].querySelector('a');
            const paras = cells[0].querySelectorAll('p');
            const cell = scoreCell(cells[3]);
            rows.push({
                title: text(link),
                genre: text(paras[0]),
                artist: text(paras[1]),
                difficulty: text(cells[1]),
                level: parseInt(text(cells[2]), 10) || level,
                score: cell.score, medal: cell.medal, rank: cell.rank
            });
        });
        return rows;
    }

    function totalPages(doc) {
        const last = doc.querySelector('select#s_page option:last-child');
        const value = last ? parseInt(last.value, 10) : 0;
        return isNaN(value) ? 1 : value + 1;
    }

    function levelURL(level, page) {
        return basePath + '/playdata/mu_lv.html?page=' + page + '&version=' + verAll
            + '&bemani=0&category=0&keyword=&lv=' + level + '&sort=music&sort_type=up';
    }

    const profile = parseProfile(await fetchDoc(basePath + '/playdata/index.html'));

    const seen = new Set();
    const rows = [];
    let levelsDone = 0;
    let nextLevel = 1;

    function addRows(pageRows) {
        pageRows.forEach(function(row) {
            if (!row.title || !row.difficulty) { return; }
            const key = row.title + '|' + row.genre + '|' + row.difficulty.toUpperCase();
            if (seen.has(key)) { return; }
            seen.add(key);
            rows.push(row);
        });
    }

    async function scrapeLevel(level) {
        const firstDoc = await fetchDoc(levelURL(level, 0));
        const firstRows = parseLevelPage(firstDoc, level);
        addRows(firstRows);
        if (firstRows.length === 0) { return; }
        const pages = Math.min(totalPages(firstDoc), 100);
        for (let page = 1; page < pages; page++) {
            const pageRows = parseLevelPage(await fetchDoc(levelURL(level, page)), level);
            if (pageRows.length === 0) { break; }
            addRows(pageRows);
        }
    }

    async function worker() {
        while (nextLevel <= maxLevel) {
            const level = nextLevel++;
            let lastError = null;
            for (let attempt = 0; attempt < 3; attempt++) {
                try {
                    await scrapeLevel(level);
                    lastError = null;
                    break;
                } catch (error) {
                    if (error && error.sentinel) { throw error; }
                    lastError = error;
                    await new Promise(function(resolve) { setTimeout(resolve, 600 * (attempt + 1)); });
                }
            }
            if (lastError) { throw lastError; }
            levelsDone++;
            if (window.webkit && window.webkit.messageHandlers
                && window.webkit.messageHandlers.popnProgress) {
                window.webkit.messageHandlers.popnProgress.postMessage({ done: levelsDone, total: maxLevel });
            }
        }
    }

    const workers = [];
    for (let i = 0; i < workerCount; i++) { workers.push(worker()); }
    await Promise.all(workers);

    if (rows.length === 0) { return 'ERR:empty'; }
    return JSON.stringify({ profile: profile, rows: rows });
}

try {
    return await fetchPopnScoreData(basePath, verAll);
} catch (error) {
    if (error && error.sentinel) { return 'ERR:' + error.sentinel; }
    return 'ERR:network';
}
"""

let scoreDataReadBody = """
function readScoreData() {
    const node = document.getElementById('score_data');
    if (node) {
        const value = (node.value !== undefined && node.value !== null && node.value !== '')
            ? node.value
            : (node.getAttribute('value') || node.textContent || '');
        const csv = (value || '').trim();
        if (csv.length > 0) { return csv; }
    }
    if (location.href.indexOf('/error/error.html') !== -1) {
        const match = location.href.match(/[?&]err=([0-9]+)/);
        return 'ERR:' + (match ? match[1] : 'server');
    }
    if (document.querySelector('#dl-data a[href*="coop/mall.html"]')) {
        return 'ERR:premiumPass';
    }
    return 'ERR:empty';
}
return readScoreData();
"""

let iidxTowerCleanup = """
var injectedCSS = `
#base {
    padding-top: 0 !important;
    background-image: unset !important;
}

#base::before {
    top: 0 !important;
}

#base::after {
    background: unset !important;
}

@media screen and (max-width:480px) {
    #base-inner {
        padding: 8px 0 8px 0;
    }

    #error-page {
        padding: 0 !important;
    }
}

@media screen and (min-width:481px) {
    #base-inner {
        padding: 20px 0 20px 0;
    }
}

@media (prefers-color-scheme: light) {
    body {
        background-color: white;
    }
}

@media (prefers-color-scheme: dark) {
    body {
        background-color: black;
    }

    #iidx-tower {
        background: black !important;
        color: white !important;
    }

    #iidx-tower table td {
        background: #1C1C1E;
        color: white;
    }

    #iidx-tower table th, #iidx-tower table td {
        border: 1px solid #46464A;
    }

    #tower-graph {
        background: #1C1C1E !important;
        color: white !important;
    }

    #tower-graph > .inner > .inner {
        border-bottom: 1px solid white;
        border-left: 1px solid white;
    }
}
`

style.appendChild(document.createTextNode(injectedCSS))
head.appendChild(style)
"""

let konamiIDLoginAutofillUserScript = """
(function() {
    var email = DJDX_KONAMI_ID_EMAIL;
    var stateKey = 'djdx-konami-id-autologin';
    if (!email || location.hostname.indexOf('konami.net') === -1) { return; }

    function state() {
        try { return sessionStorage.getItem(stateKey) || ''; } catch (error) { return 'blocked'; }
    }

    function setState(value) {
        try { sessionStorage.setItem(stateKey, value); } catch (error) {}
    }

    function isVisible(el) {
        return !!el && el.getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden';
    }

    function isUsable(el) {
        return isVisible(el) && !el.disabled && !el.readOnly && el.getAttribute('aria-disabled') !== 'true';
    }

    function setValue(el, value) {
        var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        setter.call(el, value);
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        el.dispatchEvent(new Event('blur', { bubbles: true }));
    }

    function labelOf(el) {
        return ((el.innerText || el.value || el.getAttribute('aria-label') || '') + '').replace(/\\s/g, '');
    }

    function clickWhenEnabled(el, attempts) {
        if (!el) { return; }
        if (isUsable(el)) { el.click(); return; }
        if (attempts > 0) { setTimeout(function() { clickWhenEnabled(el, attempts - 1); }, 250); }
    }

    function hasOtpBoxes() {
        return Array.prototype.slice.call(document.querySelectorAll('input')).some(function(el) {
            if (!isVisible(el)) { return false; }
            if (el.hasAttribute('data-djdx-otp')) { return true; }
            var autocomplete = (el.getAttribute('autocomplete') || '').toLowerCase();
            return autocomplete.indexOf('one-time-code') !== -1 || el.getAttribute('maxlength') === '1';
        });
    }

    function emailInput() {
        var candidates = document.querySelectorAll(
            'input[type="email"], input[autocomplete~="username"], input[autocomplete~="email"], '
            + 'input[name*="mail" i], input[id*="mail" i]'
        );
        return Array.prototype.slice.call(candidates).find(isUsable) || null;
    }

    function hasPasswordInput() {
        var inputs = document.querySelectorAll('input[type="password"]');
        return Array.prototype.slice.call(inputs).some(isVisible);
    }

    function submitButton(scope) {
        var candidates = Array.prototype.slice.call(scope.querySelectorAll('button, input[type="submit"]'))
            .filter(function(el) { return isVisible(el) && !/passkey|パスキー/i.test(el.id + labelOf(el)); });
        return candidates.find(function(el) { return /login-button/i.test(el.id); })
            || candidates.find(function(el) { return /ログイン|login|次へ|next/i.test(labelOf(el)); })
            || candidates.find(function(el) { return el.type === 'submit'; })
            || null;
    }

    function otpSendButton() {
        var issueButton = document.querySelector('[id*="confirmation-code-issue"]');
        if (isUsable(issueButton)) { return issueButton; }
        var candidates = document.querySelectorAll(
            'button, input[type="submit"], input[type="button"], a[role="button"]'
        );
        return Array.prototype.slice.call(candidates).find(function(el) {
            if (!isUsable(el)) { return false; }
            var label = labelOf(el);
            if (/再送|resend/i.test(label)) { return false; }
            return /ワンタイム|送信|one-time|onetime|sendcode|send/i.test(label);
        }) || null;
    }

    function fillEmail() {
        var input = emailInput();
        if (!input || (input.value && input.value !== email)) { return false; }
        setValue(input, email);
        if (hasPasswordInput()) {
            setState('filled');
            return true;
        }
        setState('email');
        var button = submitButton(input.form || input.closest('form') || document);
        setTimeout(function() { clickWhenEnabled(button, 8); }, 300);
        return true;
    }

    function sendOtp() {
        if (hasOtpBoxes() || emailInput()) { return false; }
        var button = otpSendButton();
        if (!button) { return false; }
        setState('sent');
        clickWhenEnabled(button, 8);
        return true;
    }

    function step() {
        var current = state();
        if (current === '') { return fillEmail(); }
        if (current === 'email') { return sendOtp(); }
        return true;
    }

    var observer = new MutationObserver(function() {
        var current = state();
        if (current !== '' && current !== 'email') { observer.disconnect(); return; }
        step();
    });

    function start() {
        step();
        if (state() === '' || state() === 'email') {
            observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true });
            setTimeout(function() { observer.disconnect(); }, 600000);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
"""
