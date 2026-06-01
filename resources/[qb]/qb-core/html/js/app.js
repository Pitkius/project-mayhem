import { determineStyleFromVariant, fetchNotifyConfig, NOTIFY_CONFIG } from "./config.js";

const { useQuasar } = Quasar;
const { onMounted, onUnmounted } = Vue;

/** Seni Material Icons pavadinimai iš config — map į FA (jei config dar neatnaujintas). */
const LEGACY_ICON_MAP = {
    check_circle: "fas fa-circle-check",
    notifications: "fas fa-circle-info",
    warning: "fas fa-triangle-exclamation",
    error: "fas fa-circle-exclamation",
    local_police: "fas fa-shield-halved",
};

function normalizeNotifyIcon(icon) {
    if (!icon || typeof icon !== "string") return undefined;
    if (icon.includes("fa-")) return icon;
    return LEGACY_ICON_MAP[icon] || undefined;
}

function notifyPosition() {
    const p = NOTIFY_CONFIG?.NotificationStyling?.position;
    const allowed = new Set([
        "top-left",
        "top-right",
        "bottom-left",
        "bottom-right",
        "top",
        "bottom",
        "left",
        "right",
        "center",
    ]);
    if (p && allowed.has(p)) return p;
    return "top-right";
}

const fetchNui = async (evName, data) => {
    const resourceName = window.GetParentResourceName();

    const rawResp = await fetch(`https://${resourceName}/${evName}`, {
        body: JSON.stringify(data),
        headers: {
            "Content-Type": "application/json; charset=UTF8",
        },
        method: "POST",
    });

    return await rawResp.json();
};

window.fetchNui = fetchNui;

const app = Vue.createApp({
    setup() {
        const $q = useQuasar();

        const showNotif = async ({ data }) => {
            if (data?.action !== "notify") return;

            const { text, length, type, caption, icon: dataIcon } = data;
            let { classes, icon } = determineStyleFromVariant(type);

            if (dataIcon) {
                icon = dataIcon;
            }
            icon = normalizeNotifyIcon(icon);

            if (!NOTIFY_CONFIG) {
                console.error("The notification config did not load properly, trying again for next time");
                await fetchNotifyConfig();
                if (NOTIFY_CONFIG) return showNotif({ data });
            }

            $q.notify({
                message: text,
                multiLine: text.length > 100,
                group: NOTIFY_CONFIG.NotificationStyling.group ?? false,
                progress: NOTIFY_CONFIG.NotificationStyling.progress ?? true,
                position: NOTIFY_CONFIG.NotificationStyling.position ?? "right",
                timeout: length,
                caption,
                classes,
                icon,
            });
        };
        onMounted(async () => {
            await fetchNotifyConfig();
            const styling = NOTIFY_CONFIG?.NotificationStyling || {};
            $q.notify.setDefaults({
                group: styling.group === true,
                position: notifyPosition(),
                progress: styling.progress !== false,
            });
            window.addEventListener("message", showNotif);
        });
        onUnmounted(() => {
            window.removeEventListener("message", showNotif);
        });
        return {};
    },
});

app.use(Quasar, { config: {}, iconSet: Quasar.iconSet.fontawesomeV6 });
app.mount("#q-app");
