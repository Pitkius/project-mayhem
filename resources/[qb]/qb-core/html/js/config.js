export let NOTIFY_CONFIG = null;

const defaultConfig = {
    NotificationStyling: {
        group: false,
        position: "top-right",
        progress: true,
    },
    VariantDefinitions: {
        success: {
            classes: "success",
            icon: "fas fa-check",
        },
        primary: {
            classes: "primary",
            icon: "fas fa-circle-info",
        },
        info: {
            classes: "info",
            icon: "fas fa-circle-info",
        },
        warning: {
            classes: "warning",
            icon: "fas fa-triangle-exclamation",
        },
        error: {
            classes: "error",
            icon: "fas fa-xmark",
        },
        police: {
            classes: "police",
            icon: "fas fa-shield-halved",
        },
        ambulance: {
            classes: "ambulance",
            icon: "fas fa-truck-medical",
        },
    },
};

export const determineStyleFromVariant = (variant) => {
    const variantData = NOTIFY_CONFIG.VariantDefinitions[variant];
    if (!variantData) {
        return NOTIFY_CONFIG.VariantDefinitions.primary || defaultConfig.VariantDefinitions.primary;
    }
    return variantData;
};

export const fetchNotifyConfig = async () => {
    try {
        NOTIFY_CONFIG = await window.fetchNui("getNotifyConfig", {});
        if (!NOTIFY_CONFIG) {
            NOTIFY_CONFIG = defaultConfig;
        }
        if (!NOTIFY_CONFIG.VariantDefinitions) {
            NOTIFY_CONFIG.VariantDefinitions = defaultConfig.VariantDefinitions;
        }
        if (!NOTIFY_CONFIG.NotificationStyling) {
            NOTIFY_CONFIG.NotificationStyling = defaultConfig.NotificationStyling;
        }
    } catch (error) {
        console.error("Failed to fetch notification config, using default", error);
        NOTIFY_CONFIG = defaultConfig;
    }
};

const resourceName = () => {
    try {
        if (typeof GetParentResourceName === "function") {
            return GetParentResourceName();
        }
    } catch (e) {}
    return "qb-core";
};

window.fetchNui = async (evName, data) => {
    const rawResp = await fetch(`https://${resourceName()}/${evName}`, {
        body: JSON.stringify(data || {}),
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        method: "POST",
    });
    return await rawResp.json();
};
