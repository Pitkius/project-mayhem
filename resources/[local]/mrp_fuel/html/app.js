const res = typeof GetParentResourceName === "function" ? GetParentResourceName() : "mrp_fuel";
const $ = (s) => document.querySelector(s);

function nui(ev, data = {}) {
  return fetch(`https://${res}/${ev}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => ({}));
}

function paint(data) {
  const pct = Math.max(0, Math.min(100, Number(data.fuel) || 0));
  $("#fuelBarFill").style.width = `${pct}%`;
  $("#fuelPct").textContent = `${pct.toFixed(1)}%`;
  $("#fuelLiters").textContent = `${(Number(data.liters) || 0).toFixed(1)} L`;
  $("#fuelCost").textContent = `${Math.round(Number(data.cost) || 0)} €`;
  $("#fuelTarget").textContent = `${Math.round(Number(data.target) || 100)}%`;
  $("#fuelSub").textContent = data.label || "Pildomas kuras…";
  $("#fuelPayRow").classList.toggle("hidden", !data.choosePay);
}

window.addEventListener("message", (e) => {
  const { action, data } = e.data || {};
  if (action === "open") {
    $("#fuelUi").classList.remove("hidden");
    paint(data || {});
  }
  if (action === "update") paint(data || {});
  if (action === "close") $("#fuelUi").classList.add("hidden");
});

$("#fuelCancel")?.addEventListener("click", () => nui("fuelCancel"));
document.querySelectorAll("[data-pay]").forEach((btn) => {
  btn.addEventListener("click", () => nui("fuelChoosePay", { method: btn.dataset.pay }));
});
