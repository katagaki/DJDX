package com.tsubuzaki.djdxgo.importer

object ImporterJavaScript {

    const val BRIDGE_NAME = "DJDXAndroid"

    val globalFunctions = """
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
""".trimIndent()

    val globalCleanup = """
var disableSelectionCSS = '*{-webkit-touch-callout:none;-webkit-user-select:none}'
style.appendChild(document.createTextNode(disableSelectionCSS))
head.appendChild(style)

waitForElementToExist('#id_nav_menu_1').then((element) => {
    document.getElementById('id_nav_menu_1').remove()
})
waitForElementToExist('#menu-sp').then((element) => {
    document.getElementById('menu-sp').remove()
})
waitForElementToExist('#menu-pc').then((element) => {
    document.getElementById('menu-pc').remove()
})

waitForElementToExist('#log-on').then((element) => {
    document.getElementById('log-on').remove()
})

waitForElementToExist('#page-title').then((element) => {
    document.getElementById('page-title').remove()
})

document.body.style.setProperty('margin-bottom', '0', 'important')
waitForElementToExist('footer').then((element) => {
    document.getElementsByTagName('footer')[0].remove()
})
waitForElementToExist('#synalio-iframe').then((element) => {
    document.getElementById('synalio-iframe').remove()
})

waitForElementToExist('#onetrust-consent-sdk').then((element) => {
    document.getElementById('onetrust-consent-sdk').remove()
})

waitForElementToExist('#page-top').then((element) => {
    document.getElementById('page-top').remove()
})
""".trimIndent()

    val loginPageDarkMode = """
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
""".trimIndent()

    val loginPageCleanup = """
waitForElementToExist('.fs-6').then((element) => {
    document.getElementsByClassName('fs-6')[0].remove()
})
""".trimIndent()

    val otpAutofill = """
(function() {
    function isOtpBox(el) {
        if (!el || el.tagName !== 'INPUT') { return false; }
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
        var chars = (data || '').replace(/\s/g, '').split('');
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

    document.addEventListener('beforeinput', function(event) {
        var target = event.target;
        if (!isOtpBox(target)) { return; }
        var data = event.data;
        if (data && data.length > 1) {
            var boxes = otpBoxes(target);
            event.preventDefault();
            distribute(boxes, indexOfTarget(boxes, target), data);
        }
    }, true);

    document.addEventListener('input', function(event) {
        var target = event.target;
        if (!isOtpBox(target)) { return; }
        if (target.value && target.value.length > 1) {
            var boxes = otpBoxes(target);
            var data = target.value;
            setValue(target, '');
            distribute(boxes, indexOfTarget(boxes, target), data);
        }
    }, true);

    document.addEventListener('paste', function(event) {
        var target = event.target;
        if (!isOtpBox(target)) { return; }
        var clipboard = event.clipboardData || window.clipboardData;
        var text = clipboard ? clipboard.getData('text') : '';
        if (text && text.length > 1) {
            var boxes = otpBoxes(target);
            event.preventDefault();
            distribute(boxes, indexOfTarget(boxes, target), text);
        }
    }, true);
})();
""".trimIndent()

    private val iidxScoreDataReadBody = """
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
    return 'ERR:empty';
}
return readScoreData();
""".trimIndent()

    private val sdvxScoreDataFetchBody = """
async function fetchSDVXScoreData() {
    let csv = document.getElementById('score_data').value;
    if (csv.indexOf('楽曲名') !== -1) { return csv; }
    return 'ERR:empty';
}

return await fetchSDVXScoreData();
""".trimIndent()

    private val polarisChordScoreDataFetchBody = """
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
""".trimIndent()

    private val ddrScoreDataFetchBody = """
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
            if (window.${BRIDGE_NAME} && window.${BRIDGE_NAME}.onScrapeProgress) {
                window.${BRIDGE_NAME}.onScrapeProgress(pagesFetched);
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
""".trimIndent()

    val cleanupScript = "$globalFunctions\n$globalCleanup\n$loginPageCleanup"

    fun extraction(body: String, token: String): String = """
(async function() {
$body
})().then(function(result) {
    window.$BRIDGE_NAME.onExtractionResult('$token', String(result));
}).catch(function(error) {
    window.$BRIDGE_NAME.onExtractionResult('$token', 'ERR:network');
});
""".trimIndent()

    fun iidxScoreDataRead(token: String) = extraction(iidxScoreDataReadBody, token)
    fun sdvxScoreDataFetch(token: String) = extraction(sdvxScoreDataFetchBody, token)
    fun polarisChordScoreDataFetch(token: String) = extraction(polarisChordScoreDataFetchBody, token)
    fun ddrScoreDataFetch(token: String) = extraction(ddrScoreDataFetchBody, token)
}
