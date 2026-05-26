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

// Injected at document start so the theme is present before first paint and persists
// across the login SPA's re-renders. Selectors are intentionally broad/structural because
// KONAMI's CSS-module class names carry hashes that drift between deployments.
let loginPageDarkModeUserScript = """
(function() {
    var darkModeCSS = `
@media (prefers-color-scheme: dark) {
    html, body, #id_ea_common_content_whole, #base, #base-inner, main, [class*="Layout"] {
        background-color: #000000 !important;
        color: #ffffff !important;
    }
    header,
    [class*="Header"],
    [class*="Header_logo__konami--default"] {
        background-color: #000000 !important;
    }
    [class*="Form_login__layout"],
    [class*="Form_login__form"],
    [class*="Card"],
    .card,
    #email-form {
        border: unset !important;
        background-color: #1c1c1e !important;
    }
    label,
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
    a {
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

// Injected at document start. iOS keyboard autofill of a one-time code drops the whole
// code into the first box of a split OTP input (each box has maxlength="1"), so only the
// first digit survives truncation. This intercepts the multi-character insertion and
// distributes the digits across the boxes, dispatching native events so the SPA registers
// each one. Selectors must be validated against the live 2FA DOM.
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
var levelSelectors = document.getElementsByName("djauto_opt")[0];
levelSelectors.value = "%@1";

var songNameTextField = document.getElementsByName("djauto")[0];
songNameTextField.value = "%@2";

do_djauto();
"""
