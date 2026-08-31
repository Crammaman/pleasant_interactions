import { Controller } from "@hotwired/stimulus"

// Colour-scheme switch. Sets data-theme on <html>, which theme.css reads, and
// stores the choice so the inline script in the layout's <head> can re-apply it
// before first paint on the next load. That script has to stay inline: Stimulus
// connects after the first paint, so leaving it to this controller would show a
// flash of the wrong scheme.
//
// While nothing is stored the attribute stays absent and the page follows the
// OS, so the switch reads its own state from the OS in that case.
export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    this.systemPreference = window.matchMedia("(prefers-color-scheme: dark)")
    this.systemPreferenceChanged = this.systemPreferenceChanged.bind(this)
    this.systemPreference.addEventListener("change", this.systemPreferenceChanged)
    this.render()
  }

  disconnect() {
    this.systemPreference.removeEventListener("change", this.systemPreferenceChanged)
  }

  toggle() {
    this.apply(this.checkboxTarget.checked ? "dark" : "light")
  }

  // Only meaningful while no explicit choice is stored, when the page is still
  // tracking the OS and the switch needs to follow it.
  systemPreferenceChanged() {
    if (!this.chosenTheme) this.render()
  }

  apply(theme) {
    document.documentElement.setAttribute("data-theme", theme)

    try {
      localStorage.setItem("theme", theme)
    } catch (error) {
      // localStorage throws in some private-browsing modes. The switch still
      // works for this page; the choice just will not outlive it.
    }

    this.render()
  }

  render() {
    this.checkboxTarget.checked = this.currentTheme === "dark"
  }

  get chosenTheme() {
    const theme = document.documentElement.getAttribute("data-theme")
    return theme === "light" || theme === "dark" ? theme : null
  }

  get currentTheme() {
    return this.chosenTheme || (this.systemPreference.matches ? "dark" : "light")
  }
}
