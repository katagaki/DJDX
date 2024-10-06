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

let loginPageCleanup = """
// ダークモード
var darkModeCSS = `
@media (prefers-color-scheme: dark) {
    body, #id_ea_common_content_whole {
        background-color: #000000;
        color: #ffffff;
    }
    header, .Header_logo__konami--default__lYPft {
        background-color: #000000!important;
    }
    .Form_login__layout--narrow-frame__SnckF,
    .Form_login__layout--default__bEjGz,
    .Form_login__form--default__3G_u1,
    .Form_login__form--narrow-frame__Rvksw,
    #email-form {
        border: unset;
        background-color: #1c1c1e!important;
    }
    .form-control, .form-control:focus {
        background-color: #000000!important;
        color: #fff!important;
    }
    .card {
        background-color: #1c1c1e!important;
    }
}

@media (prefers-color-scheme: light) {
    body {
        background-color: #ffffff;
        color: #000000;
    }
}
`
style.appendChild(document.createTextNode(darkModeCSS))
head.appendChild(style)

// チャットポップアップを取り除く
waitForElementToExist('.fs-6').then((element) => {
    document.getElementsByClassName('fs-6')[0].remove()
})

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
`

style.appendChild(document.createTextNode(injectedCSS))
head.appendChild(style)
"""
