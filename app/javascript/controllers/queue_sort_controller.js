import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-and-drop ordering for a queue's conversation cards, backed by SortableJS.
//
// A card is dragged by its whole header. `delayOnTouchOnly` keeps that from
// eating vertical scrolling on touch devices: a swipe over the header still
// pans the page, and only a short press-and-hold starts a drag. A mouse drag
// stays immediate.
//
// The in-progress conversation is pinned to the top: its header is not a handle
// and it is marked is-locked, which `filter` uses to refuse dragging it, while
// `onMove` refuses dropping anything above it. Both are needed — `filter` alone
// would still let other cards slide past it.
//
// `preventOnFilter` has to be off: SortableJS tests `filter` before `handle`,
// so with it on, every mousedown inside the in-progress card would be
// preventDefault-ed and its expand toggle and Finish button would stop working.
//
// Order is saved by PATCHing the ids in their new top-to-bottom order. The DOM
// is already correct when that request goes out, so a failure is reconciled by
// reloading rather than by animating cards back.
export default class extends Controller {
  static targets = ["list"]
  static values = { url: String }

  connect() {
    this.savedIds = this.conversationIds
    this.sortable = Sortable.create(this.listElement, {
      handle: "[data-queue-sort-handle]",
      filter: ".is-locked",
      preventOnFilter: false,
      draggable: "[data-conversation-id]",
      delay: 200,
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      animation: 150,
      ghostClass: "is-drag-ghost",
      chosenClass: "is-dragging",
      onMove: (event) => !event.related?.classList.contains("is-locked"),
      onEnd: () => this.save()
    })
  }

  disconnect() {
    this.sortable?.destroy()
    this.sortable = null
    this.savedIds = null
  }

  async save() {
    const ids = this.conversationIds

    if (this.sameOrder(ids)) return

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          Accept: "application/json"
        },
        body: JSON.stringify({ conversation_ids: ids })
      })

      if (!response.ok) throw new Error(`Reorder failed with ${response.status}`)

      this.savedIds = ids
    } catch (error) {
      // The cards are sitting in an order the server did not accept, so pull
      // the authoritative order back rather than leave the two disagreeing.
      console.error(error)
      window.location.reload()
    }
  }

  get conversationIds() {
    return Array.from(
      this.listElement.querySelectorAll("[data-conversation-id]"),
      (card) => card.dataset.conversationId
    )
  }

  sameOrder(ids) {
    return this.savedIds?.length === ids.length && this.savedIds.every((id, index) => id === ids[index])
  }

  get listElement() {
    return this.hasListTarget ? this.listTarget : this.element
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
