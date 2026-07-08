const res = typeof GetParentResourceName === "function" ? GetParentResourceName() : "mrp_fuel";
const $ = (s) => document.querySelector(s);

function nui(ev, data = {}) {
  return fetch(`https://${res}/${ev}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => ({}));
}

function setPayButtons(enabled, activeMethod) {
  document.querySelectorAll("[data-pay]").forEach((btn) => {
    btn.disabled = !enabled;
    btn.classList.toggle("active", activeMethod && btn.dataset.pay === activeMethod);
  });
}

function paint(data) {
  const pct = Math.max(0, Math.min(100, Number(data.fuel) || 0));
  $("#fuelBarFill").style.width = `${pct}%`;
  $("#fuelPct").textContent = `${pct.toFixed(1)}%`;
  $("#fuelLiters").textContent = `${(Number(data.liters) || 0).toFixed(1)} L`;
  $("#fuelCost").textContent = `${Math.round(Number(data.cost) || 0)} €`;
  $("#fuelTarget").textContent = `${Math.round(Number(data.target) || 100)}%`;
  $("#fuelSub").textContent = data.label || "Pildomas kuras…";
  const choosePay = !!data.choosePay;
  $("#fuelPayRow").classList.toggle("hidden", !choosePay);
  setPayButtons(choosePay, choosePay ? null : null);
}

window.addEventListener("message", (e) => {
  const { action, data } = e.data || {};
  if (action === "open") {
    $("#fuelUi").classList.remove("hidden");
    setPayButtons(true, null);
    paint(data || {});
  }
  if (action === "update") paint(data || {});
  if (action === "close") {
    $("#fuelUi").classList.add("hidden");
    setPayButtons(false, null);
  }
});

$("#fuelCancel")?.addEventListener("click", () => nui("fuelCancel"));

document.querySelectorAll("[data-pay]").forEach((btn) => {
  btn.addEventListener("click", () => {
    if (btn.disabled) return;
    setPayButtons(false, btn.dataset.pay);
    nui("fuelChoosePay", { method: btn.dataset.pay });
  });
});
