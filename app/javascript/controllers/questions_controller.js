import { Controller } from "@hotwired/stimulus"

// The question builder shared by the new and edit user forms: add, remove and
// reorder rows, show the options box only for the types that use it, and (on
// the new-user form) seed the rows from an existing profile.
export default class extends Controller {
  static targets = ["list", "template", "section", "converser", "copyFrom"]
  static values = { profiles: Object }

  connect() {
    this.refresh()
  }

  add() {
    this.appendRow()
  }

  remove(event) {
    this.rowFor(event).remove()
    this.refresh()
  }

  moveUp(event) {
    const row = this.rowFor(event)
    const previous = row.previousElementSibling
    if (previous) this.listTarget.insertBefore(row, previous)
  }

  moveDown(event) {
    const row = this.rowFor(event)
    const next = row.nextElementSibling
    if (next) this.listTarget.insertBefore(next, row)
  }

  // Replaces every row with the questions of the profile being copied from.
  copy() {
    const questions = this.profilesValue[this.copyFromTarget.value] || []

    this.listTarget.innerHTML = ""
    questions.forEach((question) => this.appendRow(question))
    this.refresh()
  }

  // Hides the options box for types that don't use it, and keeps the whole
  // section out of the submission while the user isn't a converser.
  refresh() {
    const enabled = this.converserOn

    this.rows.forEach((row) => {
      const needsOptions = ["select", "radio"].includes(row.querySelector("[data-question-type]").value)
      const optionsField = row.querySelector("[data-question-options]")

      optionsField.classList.toggle("is-hidden", !needsOptions)
      row.querySelectorAll("input, select, textarea").forEach((field) => { field.disabled = !enabled })
      optionsField.querySelector("textarea").disabled = !enabled || !needsOptions
    })

    if (this.hasSectionTarget) this.sectionTarget.classList.toggle("is-hidden", !enabled)
  }

  appendRow(question = null) {
    const row = this.templateTarget.content.firstElementChild.cloneNode(true)

    if (question) {
      row.querySelector("[data-question-text]").value = question.text || ""
      row.querySelector("[data-question-type]").value = question.question_type || "text"
      row.querySelector("[data-question-options] textarea").value = (question.options || []).join("\n")
    }

    this.listTarget.appendChild(row)
    this.refresh()
  }

  get rows() {
    return Array.from(this.listTarget.querySelectorAll(":scope > [data-question-row]"))
  }

  rowFor(event) {
    return event.target.closest("[data-question-row]")
  }

  // A form without the checkbox is editing a profile that already exists.
  get converserOn() {
    return !this.hasConverserTarget || this.converserTarget.checked
  }
}
