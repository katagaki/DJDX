//
//  JavaScript.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

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

// SDVX: the score data page (playdata/index.html) exposes its CSV by POSTing
// method=display to itself (the disp_data() function). The response body is an
// HTML page whose <pre>/<textarea> contains the CSV text; we POST and return
// the CSV string.
let sdvxScoreDownloadFetchBody = """
async function fetchSDVXScoreData() {
    let csv = document.getElementById('score_data').value;
    if (csv.indexOf('楽曲名') !== -1) { return csv; }
    return 'ERR:empty';
}
    
return await fetchSDVXScoreData();
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

let textageNavigationJS = """
(function() {
    var levelSelector = document.getElementsByName("djauto_opt")[0];
    var songNameTextField = document.getElementsByName("djauto")[0];
    if (!levelSelector || !songNameTextField) { return; }

    levelSelector.value = "%@1";
    songNameTextField.value = "%@2";

    var autoCompleteForm = songNameTextField.form;
    if (autoCompleteForm) {
        var namedRef = document.getElementsByName("ref");
        for (var i = namedRef.length - 1; i >= 0; i--) {
            if (namedRef[i] !== autoCompleteForm) {
                namedRef[i].setAttribute("name", "ref_search");
            }
        }
        autoCompleteForm.setAttribute("name", "ref");
    }

    if (typeof do_djauto === "function") { do_djauto(); }
})();
"""
