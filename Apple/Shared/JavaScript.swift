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

let gitadoraScoreDataFetchBody = #"""
async function fetchGITADORAScoreData() {
    const base = new URL('./', location.href).href;
    const diffNames = ['BASIC', 'ADVANCED', 'EXTREME', 'MASTER'];
    const diffCodes = { BAS: 'BASIC', ADV: 'ADVANCED', EXT: 'EXTREME', MAS: 'MASTER' };
    const partCodes = { G: 'GUITAR', B: 'BASS', D: 'DRUM' };
    const rankSet = ['SS', 'S', 'A', 'B', 'C', 'D', 'E'];
    const gameTypes = [{ gtype: 'gf', parts: ['GUITAR', 'BASS'] },
                       { gtype: 'dm', parts: ['DRUM'] }];
    const categoryCount = 37;
    const totalSteps = 5 + categoryCount * gameTypes.length;
    let step = 0;
    let detailFailures = 0;
    let detailsEnabled = true;

    function report() {
        step++;
        if (window.webkit && window.webkit.messageHandlers
            && window.webkit.messageHandlers.gitadoraProgress) {
            window.webkit.messageHandlers.gitadoraProgress.postMessage({ step: step, total: totalSteps });
        }
        if (window.DJDXAndroid && window.DJDXAndroid.onScrapeStep) {
            window.DJDXAndroid.onScrapeStep(step, totalSteps);
        }
    }

    function sleep(ms) { return new Promise(function(resolve) { setTimeout(resolve, ms); }); }

    async function decode(response) {
        const buffer = await response.arrayBuffer();
        let charset = ((response.headers.get('content-type') || '').match(/charset=([^;]+)/i) || [])[1];
        if (!charset) {
            const head = new TextDecoder('utf-8').decode(buffer.slice(0, 4096));
            charset = (head.match(/charset=["']?([A-Za-z0-9_-]+)/i) || [])[1];
        }
        try {
            return new TextDecoder((charset || 'utf-8').trim().toLowerCase()).decode(buffer);
        } catch (error) {
            return new TextDecoder('utf-8').decode(buffer);
        }
    }

    async function fetchPage(url) {
        const response = await fetch(url, { method: 'GET', credentials: 'same-origin' });
        const finalURL = response.url || '';
        if (finalURL.indexOf('/error/') !== -1 || finalURL.indexOf('login.html') !== -1) {
            const match = finalURL.match(/[?&]err=([0-9]+)/);
            return { error: match ? match[1] : 'server' };
        }
        if (!response.ok) { return { error: 'server' }; }
        const html = await decode(response);
        if (/メンテナンス/.test(html) && !/music_detail|skill_table|profile_name/.test(html)) {
            return { error: 'maintenance' };
        }
        return { doc: new DOMParser().parseFromString(html, 'text/html'), url: finalURL || url };
    }

    function text(element) {
        return element ? element.textContent.replace(/\s+/g, ' ').trim() : '';
    }

    function classOf(element) {
        return (element && element.getAttribute && element.getAttribute('class')) || '';
    }

    function rankFromClass(className) {
        const tokens = className.split(/\s+/);
        for (const token of tokens) {
            if (!token || token.indexOf('score_data') === 0 || token.indexOf('zebra') === 0) { continue; }
            const value = (token.indexOf('icon') === 0 ? token.slice(4) : token).toUpperCase();
            if (rankSet.indexOf(value) !== -1) { return value; }
        }
        return '';
    }

    function rankFromElement(element) {
        if (!element) { return ''; }
        const candidates = [element].concat(Array.prototype.slice.call(element.querySelectorAll('*')));
        for (const candidate of candidates) {
            const className = classOf(candidate);
            if (className.indexOf('score_data_rank') !== -1) {
                const rank = rankFromClass(className);
                if (rank) { return rank; }
            }
            if (candidate.tagName === 'IMG') {
                const stem = ((candidate.getAttribute('src') || '').split('/').pop() || '')
                    .split('.')[0].replace(/^(rank_?|icon_?)/i, '').toUpperCase();
                if (rankSet.indexOf(stem) !== -1) { return stem; }
            }
        }
        return '';
    }

    function parseNumber(value) {
        const match = value.replace(/,/g, '').match(/-?\d+(?:\.\d+)?/);
        return match ? parseFloat(match[0]) : 0;
    }

    function parseList(doc, pageURL, gameType) {
        const songs = [];
        let current = null;
        doc.querySelectorAll('tr').forEach(function(row) {
            const link = row.querySelector('a[href*="music_detail.html"]');
            const ranks = Array.prototype.slice.call(row.querySelectorAll('[class*="score_data_rank"]'))
                .map(function(cell) { return rankFromClass(classOf(cell)); });
            if (link) {
                current = { title: text(link), detail: new URL(link.getAttribute('href'), pageURL).href, ranks: {} };
                songs.push(current);
                current.ranks[gameType.parts[0]] = ranks.slice(0, 4);
                if (gameType.parts.length > 1 && ranks.length >= 8) {
                    current.ranks[gameType.parts[1]] = ranks.slice(4, 8);
                }
            } else if (current && gameType.parts.length > 1 && !current.ranks[gameType.parts[1]]
                       && ranks.length >= 4) {
                current.ranks[gameType.parts[1]] = ranks.slice(0, 4);
            }
        });
        return songs.filter(function(song) { return song.title; });
    }

    function parseDetail(doc, gameType) {
        const charts = {};
        let part = gameType.parts[0];
        let hasPartMarkers = false;
        let current = null;
        const elements = doc.body ? doc.body.querySelectorAll('*') : [];
        for (const element of elements) {
            const className = classOf(element);
            const partMatch = className.match(/md_part_(GUITAR|BASS|DRUM)/);
            if (partMatch) {
                part = partMatch[1];
                hasPartMarkers = true;
                current = null;
                continue;
            }
            const diffMatch = className.match(/(?:^|\s)diff_(BASIC|ADVANCED|EXTREME|MASTER)(?:\s|$)/);
            if (diffMatch) {
                let key = part + '|' + diffMatch[1];
                if (!hasPartMarkers && gameType.parts.length > 1 && part === gameType.parts[0]
                    && charts[key] && charts[key].hasMetrics) {
                    part = gameType.parts[1];
                    key = part + '|' + diffMatch[1];
                }
                if (!charts[key]) {
                    charts[key] = { level: '', rate: '', score: 0, playCount: 0, clearCount: 0,
                                    rank: '', excellent: false, fullCombo: false, hasMetrics: false };
                }
                current = charts[key];
                const levelMatch = text(element).match(/^(\d{1,2}\.\d{2})$/);
                if (levelMatch && !current.level) { current.level = levelMatch[1]; }
                continue;
            }
            if (!current || (element.tagName !== 'TD' && element.tagName !== 'TH')) { continue; }
            const value = element.nextElementSibling;
            if (!value) { continue; }
            const label = text(element).replace(/\s+/g, '').toUpperCase();
            const valueText = text(value);
            const valueHTML = value.innerHTML || '';
            if (label === 'プレー回数') {
                current.playCount = parseNumber(valueText);
                current.hasMetrics = true;
            } else if (label === 'クリア回数') {
                current.clearCount = parseNumber(valueText);
                current.hasMetrics = true;
            } else if (label === '最高ランク') {
                current.rank = rankFromElement(value);
                if (/excellent/i.test(valueHTML)) { current.excellent = true; }
                if (/full[\s_-]?combo/i.test(valueHTML)) { current.fullCombo = true; }
                current.hasMetrics = true;
            } else if (label === '達成率') {
                if (valueText.toUpperCase() === 'MAX') {
                    current.rate = '100.00';
                } else {
                    const rateMatch = valueText.match(/(\d{1,3}(?:\.\d+)?)\s*%/);
                    if (rateMatch) { current.rate = rateMatch[1]; }
                }
                current.hasMetrics = true;
            } else if (label === 'ハイスコア' || label === 'HIGHSCORE') {
                current.score = parseNumber(valueText);
                current.hasMetrics = true;
            } else if (label.indexOf('フルコンボ') !== -1 || label.indexOf('FULLCOMBO') !== -1) {
                if (parseNumber(valueText) > 0) { current.fullCombo = true; }
            } else if (label.indexOf('エクセレント') !== -1 || label.indexOf('EXCELLENT') !== -1) {
                if (parseNumber(valueText) > 0) { current.excellent = true; }
            }
        }
        return charts;
    }

    function parseSkill(doc) {
        const charts = [];
        const table = doc.querySelector('.skill_table_tb');
        if (!table) { return charts; }
        const body = table.querySelector('tbody') || table;
        body.querySelectorAll('tr').forEach(function(row) {
            const link = row.querySelector('a.text_link');
            const icons = row.querySelectorAll('div.music_seq_box > div');
            if (!link || icons.length < 2) { return; }
            const part = partCodes[classOf(icons[0]).substring(14, 15)];
            const difficulty = diffCodes[classOf(icons[1]).substring(14, 17)];
            const skill = parseNumber(text(row.querySelector('td.skill_cell')));
            const rateMatch = text(row.querySelector('td.achive_cell')).match(/\d+(?:\.\d+)?/);
            const levelMatch = text(row.querySelector('td.diff_cell')).match(/\d+\.\d+/);
            if (!part || !difficulty) { return; }
            charts.push({ title: text(link), part: part, difficulty: difficulty, skill: skill,
                          rate: rateMatch ? rateMatch[0] : '', level: levelMatch ? levelMatch[0] : '' });
        });
        return charts;
    }

    function clearTypeFor(chart, listRank) {
        if (chart && chart.hasMetrics) {
            if (chart.excellent || parseFloat(chart.rate) >= 100) { return 'EXCELLENT'; }
            if (chart.fullCombo) { return 'FULL COMBO'; }
            if (chart.clearCount > 0) { return 'CLEAR'; }
            if (chart.playCount > 0) { return 'FAILED'; }
        }
        if (listRank) { return listRank === 'E' ? 'FAILED' : 'CLEAR'; }
        return '';
    }

    const profilePage = await fetchPage(base + 'profile.html');
    if (profilePage.error) { return 'ERR:' + profilePage.error; }
    const profile = { name: text(profilePage.doc.querySelector('.profile_name_frame')), skill: {} };
    report();

    const skillCharts = {};
    for (const gameType of gameTypes) {
        let total = 0;
        for (const skillType of [0, 1]) {
            const page = await fetchPage(base + 'skill.html?gtype=' + gameType.gtype + '&stype=' + skillType);
            report();
            if (page.error) { continue; }
            parseSkill(page.doc).forEach(function(chart) {
                total += chart.skill;
                skillCharts[chart.title + '|' + chart.part + '|' + chart.difficulty] = chart;
            });
        }
        profile.skill[gameType.gtype] = Math.round(total * 100) / 100;
    }

    const rows = [];
    for (const gameType of gameTypes) {
        for (let category = 0; category < categoryCount; category++) {
            const listURL = base + 'music.html?gtype=' + gameType.gtype + '&cat=' + category;
            const list = await fetchPage(listURL);
            if (list.error) {
                if (category === 0 && gameType.gtype === 'gf') { return 'ERR:' + list.error; }
                report();
                continue;
            }
            const songs = parseList(list.doc, list.url, gameType);
            for (const song of songs) {
                const played = gameType.parts.some(function(part) {
                    return (song.ranks[part] || []).some(function(rank) { return rank; });
                }) || gameType.parts.some(function(part) {
                    return diffNames.some(function(diff) { return skillCharts[song.title + '|' + part + '|' + diff]; });
                });
                if (!played) { continue; }
                let detail = null;
                if (detailsEnabled) {
                    const detailURL = new URL(song.detail);
                    if (category === 0) { detailURL.searchParams.set('cat', ''); }
                    try {
                        const page = await fetchPage(detailURL.href);
                        if (page.doc) {
                            detail = parseDetail(page.doc, gameType);
                            detailFailures = 0;
                        } else {
                            detailFailures++;
                        }
                    } catch (error) {
                        detailFailures++;
                    }
                    if (detailFailures >= 3) { detailsEnabled = false; }
                    await sleep(80);
                }
                gameType.parts.forEach(function(part) {
                    const ranks = song.ranks[part] || [];
                    diffNames.forEach(function(diff, index) {
                        const listRank = ranks[index] || '';
                        const chart = detail ? detail[part + '|' + diff] : null;
                        const skill = skillCharts[song.title + '|' + part + '|' + diff];
                        const chartPlayed = chart && chart.hasMetrics && (chart.playCount > 0 || chart.rate);
                        if (!listRank && !chartPlayed && !skill) { return; }
                        rows.push({
                            title: song.title,
                            instrument: part,
                            difficulty: diff,
                            level: (chart && chart.level) || (skill && skill.level) || '',
                            rate: (chart && chart.rate) || (skill && skill.rate) || '',
                            score: chart ? chart.score : 0,
                            rank: (chart && chart.rank) || listRank,
                            clear: clearTypeFor(chart, listRank || (skill ? 'C' : ''))
                        });
                    });
                });
            }
            report();
        }
    }

    if (rows.length === 0) { return 'ERR:empty'; }
    return JSON.stringify({ profile: profile, rows: rows });
}

for (let attempt = 0; attempt < 3; attempt++) {
    try {
        return await fetchGITADORAScoreData();
    } catch (error) {
        if (attempt === 2) { return 'ERR:network'; }
        await new Promise(function(resolve) { setTimeout(resolve, 800 * (attempt + 1)); });
    }
}
return 'ERR:network';
"""#

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
