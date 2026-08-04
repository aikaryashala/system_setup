/* system_setup - shared behaviour.
   Vanilla JS, no dependencies, no network requests. */

(function () {
    'use strict';

    /* ---------------------------------------------------------- theme ---- */

    var STORAGE_KEY = 'system-setup-theme';

    function systemTheme() {
        return window.matchMedia &&
               window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }

    function storedTheme() {
        try {
            return localStorage.getItem(STORAGE_KEY);
        } catch (e) {
            return null;   // private browsing, or storage disabled
        }
    }

    function applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        var button = document.querySelector('.theme-toggle');
        if (button) {
            button.textContent = theme === 'dark' ? '☀' : '☽';
            button.setAttribute('aria-label',
                theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
        }
    }

    function initTheme() {
        applyTheme(storedTheme() || systemTheme());

        var button = document.querySelector('.theme-toggle');
        if (!button) { return; }

        button.addEventListener('click', function () {
            var next = document.documentElement.getAttribute('data-theme') === 'dark'
                ? 'light' : 'dark';
            applyTheme(next);
            try {
                localStorage.setItem(STORAGE_KEY, next);
            } catch (e) { /* nothing we can do; the choice just will not persist */ }
        });
    }

    /* --------------------------------------------------- copy buttons ---- */

    // The text to copy is the block's text minus the shell prompts and minus
    // any lines marked as program output, so a copied block can be pasted
    // straight into a terminal.
    function copyableText(pre) {
        var clone = pre.cloneNode(true);
        clone.querySelectorAll('.prompt, .out').forEach(function (node) {
            node.remove();
        });
        return clone.textContent.replace(/\n{3,}/g, '\n\n').trim();
    }

    function copyToClipboard(text) {
        if (navigator.clipboard && window.isSecureContext) {
            return navigator.clipboard.writeText(text);
        }
        // file:// and plain http previews do not get the async clipboard API.
        return new Promise(function (resolve, reject) {
            var area = document.createElement('textarea');
            area.value = text;
            area.setAttribute('readonly', '');
            area.style.position = 'fixed';
            area.style.opacity = '0';
            document.body.appendChild(area);
            area.select();
            try {
                document.execCommand('copy') ? resolve() : reject();
            } catch (e) {
                reject(e);
            } finally {
                document.body.removeChild(area);
            }
        });
    }

    function addCopyButton(pre) {
        var wrapper = pre.parentElement;

        // Wrap the <pre> so the button can be positioned against it, unless the
        // page already provided a .codeblock wrapper (needed for labels).
        if (!wrapper || !wrapper.classList.contains('codeblock')) {
            wrapper = document.createElement('div');
            wrapper.className = 'codeblock';
            pre.parentNode.insertBefore(wrapper, pre);
            wrapper.appendChild(pre);
        }

        if (wrapper.querySelector('.copy-btn')) { return; }

        var button = document.createElement('button');
        button.type = 'button';
        button.className = 'copy-btn';
        button.textContent = 'Copy';
        button.setAttribute('aria-label', 'Copy this command to the clipboard');

        button.addEventListener('click', function () {
            copyToClipboard(copyableText(pre)).then(function () {
                button.textContent = 'Copied';
                button.classList.add('copied');
                setTimeout(function () {
                    button.textContent = 'Copy';
                    button.classList.remove('copied');
                }, 1600);
            }).catch(function () {
                button.textContent = 'Press Ctrl+C';
                setTimeout(function () { button.textContent = 'Copy'; }, 2000);
            });
        });

        wrapper.appendChild(button);
    }

    function initCopyButtons() {
        document.querySelectorAll('pre').forEach(addCopyButton);
    }

    /* ---------------------------------------------------- code labels ---- */

    // <div class="codeblock" data-label="powershell"> renders the label above
    // the code, and reserves room for it.
    function initLabels() {
        document.querySelectorAll('.codeblock[data-label]').forEach(function (block) {
            if (block.querySelector('.label')) { return; }
            var label = document.createElement('span');
            label.className = 'label';
            label.textContent = block.getAttribute('data-label');
            block.classList.add('has-label');
            block.insertBefore(label, block.firstChild);
        });
    }

    /* ------------------------------------------------------------ init --- */

    function init() {
        initTheme();
        initLabels();
        initCopyButtons();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
}());
