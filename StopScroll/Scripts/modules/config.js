// Config parsing and runtime settings exposed via window.StopScroll.config.
(function (global) {
    'use strict';

    const ns = (global.StopScroll = global.StopScroll || {});
    const constants = ns.constants;

    function toValue(raw) {
        const value = (raw || '').trim();
        if (value === 'true') return true;
        if (value === 'false') return false;
        if (/^-?\d+$/.test(value)) return parseInt(value, 10);
        if (/^-?\d+\.\d+$/.test(value)) return parseFloat(value);
        return value.replace(/^['"]|['"]$/g, '');
    }

    function parseSimpleYAML(text) {
        const root = {};
        const stack = [{ indent: -1, obj: root, key: null }];
        const lines = (text || '').split(/\r?\n/);

        for (const line of lines) {
            if (!line.trim() || line.trim().startsWith('#')) {
                continue;
            }

            const indent = line.match(/^\s*/)[0].length;
            const entry = line.trim();

            // ── List item: "- value" ──────────────────────────
            if (entry.startsWith('- ')) {
                while (stack.length > 1 && indent <= stack[stack.length - 1].indent) {
                    stack.pop();
                }
                const top = stack[stack.length - 1];
                const grandparent = stack.length > 1 ? stack[stack.length - 2].obj : null;
                if (grandparent && top.key) {
                    if (!Array.isArray(grandparent[top.key])) {
                        grandparent[top.key] = [];
                    }
                    grandparent[top.key].push(toValue(entry.slice(2)));
                }
                continue;
            }

            const sepIndex = entry.indexOf(':');
            if (sepIndex < 0) {
                continue;
            }

            const key = entry.slice(0, sepIndex).trim();
            const rawValue = entry.slice(sepIndex + 1).trim();

            while (stack.length > 1 && indent <= stack[stack.length - 1].indent) {
                stack.pop();
            }

            const parent = stack[stack.length - 1].obj;
            if (!rawValue) {
                const next = {};
                parent[key] = next;
                stack.push({ indent: indent, obj: next, key: key });
            } else {
                parent[key] = toValue(rawValue);
            }
        }

        return root;
    }

    function deepMerge(base, override) {
        if (typeof base !== 'object' || base === null) {
            return override;
        }
        const out = Array.isArray(base) ? base.slice() : Object.assign({}, base);
        if (typeof override !== 'object' || override === null) {
            return out;
        }

        for (const key of Object.keys(override)) {
            const next = override[key];
            if (typeof next === 'object' && next !== null && !Array.isArray(next)) {
                out[key] = deepMerge(out[key] || {}, next);
            } else {
                out[key] = next;
            }
        }

        return out;
    }

    function loadConfig() {
        const yamlText = global.__STOPSCROLL_DYNAMIC_YAML || '';
        const parsed = parseSimpleYAML(yamlText);
        var config = deepMerge(constants.DEFAULT_CONFIG, parsed);
        // User-set injection frequency from native settings overrides YAML/defaults
        if (typeof global.__STOPSCROLL_FREQUENCY === 'number') {
            config.cards.every_n_opportunities = global.__STOPSCROLL_FREQUENCY;
        }
        return config;
    }

    function getAdLabels() {
        const injected = global.__STOPSCROLL_AD_LABELS;
        if (Array.isArray(injected) && injected.length > 0) {
            return injected
                .map(function (label) { return String(label || '').trim().toLowerCase(); })
                .filter(Boolean);
        }

        return constants.SPONSORED_LABELS;
    }

    ns.config = {
        parseSimpleYAML: parseSimpleYAML,
        deepMerge: deepMerge,
        loadConfig: loadConfig,
        getAdLabels: getAdLabels
    };
})(window);
