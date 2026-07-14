let direction = null;
let textVisible = false;
let hideTimer = null;

function applyPosition(text, position) {
    removeClass(text, "left");
    removeClass(text, "right");
    removeClass(text, "top");
    removeClass(text, "bottom");

    switch (position) {
        case "left":
            addClass(text, "left");
            direction = "left";
            break;
        case "top":
            addClass(text, "top");
            direction = "top";
            break;
        case "right":
            addClass(text, "right");
            direction = "right";
            break;
        default:
            addClass(text, "left");
            direction = "left";
            break;
    }
}

const drawText = async (textData) => {
    const text = document.getElementById("text");
    const container = document.getElementById("drawtext-container");
    if (!text || !container) return;

    if (hideTimer) {
        clearTimeout(hideTimer);
        hideTimer = null;
    }

    applyPosition(text, textData.position);
    text.innerHTML = textData.text;
    container.style.display = "block";

    if (!textVisible) {
        removeClass(text, "hide");
        removeClass(text, "pressed");
        await sleep(50);
        addClass(text, "show");
    }
    textVisible = true;
};

const changeText = async (textData) => {
    const text = document.getElementById("text");
    const container = document.getElementById("drawtext-container");
    if (!text || !container) return;

    if (hideTimer) {
        clearTimeout(hideTimer);
        hideTimer = null;
    }

    applyPosition(text, textData.position);
    text.innerHTML = textData.text;
    container.style.display = "block";

    if (textVisible && text.classList.contains("show")) {
        return;
    }

    removeClass(text, "hide");
    removeClass(text, "pressed");
    await sleep(50);
    addClass(text, "show");
    textVisible = true;
};

const hideText = async () => {
    const text = document.getElementById("text");
    const container = document.getElementById("drawtext-container");
    if (!text || !container) return;

    if (hideTimer) clearTimeout(hideTimer);

    removeClass(text, "show");
    addClass(text, "hide");

    hideTimer = setTimeout(() => {
        hideTimer = null;
        removeClass(text, "left");
        removeClass(text, "right");
        removeClass(text, "top");
        removeClass(text, "bottom");
        removeClass(text, "hide");
        removeClass(text, "pressed");
        container.style.display = "none";
        textVisible = false;
    }, 280);
};

const keyPressed = () => {
    const text = document.getElementById("text");
    if (!text) return;
    addClass(text, "pressed");
};

window.addEventListener("message", (event) => {
    const data = event.data;
    const action = data.action;
    const textData = data.data;
    switch (action) {
        case "DRAW_TEXT":
            return drawText(textData);
        case "CHANGE_TEXT":
            return changeText(textData);
        case "HIDE_TEXT":
            return hideText();
        case "KEY_PRESSED":
            return keyPressed();
        default:
            return;
    }
});

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const removeClass = (element, name) => {
    if (element && element.classList.contains(name)) {
        element.classList.remove(name);
    }
};

const addClass = (element, name) => {
    if (element && !element.classList.contains(name)) {
        element.classList.add(name);
    }
};
