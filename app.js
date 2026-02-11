const body = document.body;

const platformNameInput = document.getElementById("platformNameInput");
const platformName = document.getElementById("platform-name");
const primaryColor = document.getElementById("primaryColor");
const accentColor = document.getElementById("accentColor");
const modeSelect = document.getElementById("modeSelect");
const backgroundSelect = document.getElementById("backgroundSelect");
const hexToggle = document.getElementById("hexToggle");
const hexOpacity = document.getElementById("hexOpacity");
const spacingSelect = document.getElementById("spacingSelect");

platformNameInput.addEventListener("input", (event) => {
  platformName.textContent = event.target.value || "MyBusiness Payroll";
});

primaryColor.addEventListener("input", (event) => {
  body.style.setProperty("--primary", event.target.value);
});

accentColor.addEventListener("input", (event) => {
  body.style.setProperty("--accent", event.target.value);
});

modeSelect.addEventListener("change", (event) => {
  body.dataset.mode = event.target.value;
});

backgroundSelect.addEventListener("change", (event) => {
  if (event.target.value === "soft-gradient" && body.dataset.mode !== "light") {
    body.style.background = "linear-gradient(140deg, #101015 0%, #171921 52%, #222013 100%)";
    return;
  }

  body.style.background = "";
});

hexToggle.addEventListener("change", (event) => {
  body.dataset.hex = event.target.value;
});

hexOpacity.addEventListener("input", (event) => {
  const value = Number(event.target.value) / 100;
  body.style.setProperty("--hex-opacity", value.toFixed(2));
});

spacingSelect.addEventListener("change", (event) => {
  body.dataset.spacing = event.target.value;
});
