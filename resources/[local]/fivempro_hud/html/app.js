const hud = document.getElementById("hud");
const armorRow = document.getElementById("armor-row");
const carHud = document.getElementById("carhud");
const speedText = document.getElementById("speed");
const fuelText = document.getElementById("fuel");
const engineText = document.getElementById("engine");
const seatbeltText = document.getElementById("seatbelt");
const cashText = document.getElementById("cash");
const bankText = document.getElementById("bank");

const bars = {
  health: document.getElementById("health"),
  armor: document.getElementById("armor"),
  hunger: document.getElementById("hunger"),
  thirst: document.getElementById("thirst"),
};

function setBar(name, value) {
  const clamped = Math.max(0, Math.min(100, Number(value) || 0));
  bars[name].style.width = `${clamped}%`;
}

window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data || data.action !== "update") return;

  hud.style.display = data.show ? "flex" : "none";
  armorRow.classList.toggle("hidden", !data.showArmor);

  setBar("health", data.health);
  setBar("armor", data.armor);
  setBar("hunger", data.hunger);
  setBar("thirst", data.thirst);

  carHud.classList.toggle("hidden", !data.inVehicle || !data.show);
  speedText.textContent = `${data.speed ?? 0}`;
  fuelText.textContent = `${data.fuel ?? 0}%`;
  engineText.textContent = `${data.engine ?? 0}%`;
  seatbeltText.textContent = data.seatbelt ? "ON" : "OFF";
  cashText.textContent = `$${Number(data.cash ?? 0).toLocaleString()}`;
  bankText.textContent = `$${Number(data.bank ?? 0).toLocaleString()}`;
});

