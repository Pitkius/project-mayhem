export let NOTIFY_CONFIG = null;

const defaultConfig = {
    NotificationStyling: {
        group: true,
        position: "top-right",
        progress: true,
    },
    VariantDefinitions: {
        success: {
            classes: "success",
            icon: "fas fa-circle-check",
        },
        primary: {
            classes: "primary",
            icon: "fas fa-circle-info",
        },
        error: {
            classes: "error",
            icon: "fas fa-triangle-exclamation",
        },
        police: {
            classes: "police",
            icon: "fas fa-shield-halved",
        },
        ambulance: {
            classes: "ambulance",
            icon: "fas fa-ambulance",
        },
    },
};

export const determineStyleFromVariant = (variant) => {
    const variantData = NOTIFY_CONFIG.VariantDefinitions[variant];
    if (!variantData) throw new Error(`Style of type: ${variant}, does not exist in the config`);
    return variantData;
};

export const fetchNotifyConfig = async () => {
    try {
        NOTIFY_CONFIG = await window.fetchNui("getNotifyConfig", {});
        if (!NOTIFY_CONFIG) {
            NOTIFY_CONFIG = defaultConfig;
        }
    } catch (error) {
        console.error("Failed to fetch notification config, using default", error);
        NOTIFY_CONFIG = defaultConfig;
    }
};

window.addEventListener("load", async () => {
    await fetchNotifyConfig();
});
