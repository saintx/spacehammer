(local {:filter   filter
        :get-in   get-in
        :identity identity} (require :lib.functional))
;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;;
;;; Contributors:
;;   Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;
(local {:global-filter global-filter} (require :lib.utils))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; History
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(global history {})

(fn history.push
  [self]
  "
  Append current window frame geometry to history.
  self refers to history table instance
  "
  (let [win (hs.window.focusedWindow)
        id (: win :id)
        tbl (. self id)]
    (when win
      (when (= (type tbl) :nil)
        (tset self id []))
      (when tbl
        (let [last-el (. tbl (length tbl))]
          (when (~= last-el (: win :frame))
            (table.insert tbl (: win :frame))))))))

(fn history.pop
  [self]
  "
  Go back to previous window frame geometry in history.
  self refers to history table instance
  "
  (let [win (hs.window.focusedWindow)
        id (: win :id)
        tbl (. self id)]
    (when (and win tbl)
      (let [el (table.remove tbl)
            num-of-undos (length tbl)]
        (if el
            (do
              (: win :setFrame el)
              (when (< 0 num-of-undos)
                (alert (.. num-of-undos " undo steps available"))))
            (alert "nothing to undo"))))))

(fn undo
  []
  (: history :pop))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Shared Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(var cleanup-rect identity)

(fn highlight-active-window
  []
  (when cleanup-rect
    (cleanup-rect))
  (let [rect (hs.drawing.rectangle (: (hs.window.focusedWindow) :frame))
        timer (hs.timer.doAfter .3 (fn [] (cleanup-rect)))]
    (: rect :setStrokeColor {:red 1 :blue 0 :green 1 :alpha 1})
    (: rect :setStrokeWidth 5)
    (: rect :setFill false)
    (: rect :show)
    (set cleanup-rect (fn []
                        (: timer :stop)
                        (: rect :delete)
                        (set cleanup-rect identity)))))

(fn maximize-window-frame
  []
  (: history :push)
  (: (hs.window.focusedWindow) :maximize 0)
  (highlight-active-window))

(fn center-window-frame
  []
  (: history :push)
  (let [win (hs.window.focusedWindow)]
    (: win :maximize 0)
    (hs.grid.resizeWindowThinner win)
    (hs.grid.resizeWindowShorter win)
    (: win :centerOnScreen))
  (highlight-active-window))


(fn activate-app
  [app-name]
  (hs.application.launchOrFocus app-name)
  (let [app (hs.application.find app-name)]
    (when app
      (: app :activate)
      (hs.timer.doAfter .05 highlight-active-window)
      (: app :unhide))))

(fn set-mouse-cursor-at
  [app-title]
  (let [sf (: (: (hs.application.find app-title) :focusedWindow) :frame)
        desired-point (hs.geometry.point (- (+ sf._x sf._w)
                                            (/ sf._w  2))
                                         (- (+ sf._y sf._h)
                                            (/ sf._h 2)))]
    (hs.mouse.setAbsolutePosition desired-point)))

(fn show-grid
  []
  (: history :push)
  (hs.grid.show))

(fn jump-to-last-window
  []
  (-> (global-filter)
      (: :getWindows hs.window.filter.sortByFocusedLast)
      (. 2)
      (: :focus)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Jumping Windows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn jump-window
  [arrow]
  "
  Navigate to the window nearest the current active window
  For instance if you open up emacs to the left of a web browser, activate
  emacs, then run (jump-window :l) hammerspoon will move active focus
  to the browser.
  Takes an arrow like :h :j :k :l to support vim key bindings.
  Performs side effects
  Returns nil
  "
  (let [dir {:h "West" :j "South" :k "North" :l "East"}
        space (. (hs.window.focusedWindow) :filter :defaultCurrentSpace)
        fn-name (.. :focusWindow (. dir arrow))]
    (: space fn-name nil true true)
    (highlight-active-window)))

(fn jump-window-left
  []
  (jump-window :h))

(fn jump-window-above
  []
  (jump-window :j))

(fn jump-window-below
  []
  (jump-window :k))

(fn jump-window-right
  []
  (jump-window :l))

(fn allowed-app?
  [window]
  (if (: window :isStandard)
      true
      false))

(fn jump []
  "
  Displays hammerspoon's window jump UI
  "
  (let [wns (->> (hs.window.allWindows)
                 (filter allowed-app?))]
    (hs.hints.windowHints wns nil true)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Movement\Resizing Constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local
 arrow-map
 {:k {:half [0  0  1 .5] :movement [  0 -20] :complement :h :resize "Shorter"}
  :j {:half [0 .5  1 .5] :movement [  0  20] :complement :l :resize "Taller"}
  :h {:half [0  0 .5  1] :movement [-20   0] :complement :j :resize "Thinner"}
  :l {:half [.5 0 .5  1] :movement [ 20   0] :complement :k :resize "Wider"}})

(fn grid
  [method direction]
  "
  Moves, expands, or shrinks a the active window by the next grid dimension
  Grid settings are specified in config.fnl.
  "
  (let [fn-name (.. method direction)
        f (. hs.grid fn-name)]
    (f (hs.window.focusedWindow))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Resize window by half
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn rect
  [rct]
  "
  Change a window's rect geometry which includes x, y, width, and height
  Takes a rectangle table
  Performs side-effects to move\resize the active window and update history.
  Returns nil
  "
  (: history :push)
  (let [win (hs.window.focusedWindow)]
    (when win (: win :move rct))))

(fn resize-window-halve
  [arrow]
  "
  Resize a window by half the grid dimensions specified in config.fnl.
  Takes an :h :j :k or :l arrow
  Performs a side effect to resize the active window's frame rect
  Returns nil
  "
  (: history :push)
  (rect (. arrow-map arrow :half)))

(fn resize-half-left
  []
  (resize-window-halve :h))

(fn resize-half-right
  []
  (resize-window-halve :l))

(fn resize-half-top
  []
  (resize-window-halve :k))

(fn resize-half-bottom
  []
  (resize-window-halve :j))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Resize window by increments
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn resize-by-increment
  [arrow]
  "
  Resize the active window by the next window increment
  Let's say we make the grid dimensions 4x4 and we place a window in the 1x1
  meaning first column in the first row.
  We then resize an increment right. The dimensions would now be 2x1

  Takes an arrow like :h :j :k :l
  Performs a side-effect to resize the current window to the next grid increment
  Returns nil
  "
  (let [directions {:h "Left"
                    :j "Down"
                    :k "Up"
                    :l "Right"}]
    (: history :push)
    (when (or (= arrow :h) (= arrow :l))
      (hs.grid.resizeWindowThinner (hs.window.focusedWindow)))
    (when (or (= arrow :j) (= arrow :k))
      (hs.grid.resizeWindowShorter (hs.window.focusedWindow)))
    (grid :pushWindow (. directions arrow))))

(fn resize-inc-left
  []
  (resize-by-increment :h))

(fn resize-inc-bottom
  []
  (resize-by-increment :j))

(fn resize-inc-top
  []
  (resize-by-increment :k))

(fn resize-inc-right
  []
  (resize-by-increment :l))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Resize windows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn resize-window
  [arrow]
  "
  Resizes a window against the grid specifed in config.fnl
  Takes an arrow string like :h :k :j :l
  Performs a side effect to resize the current window.
  Returns nil
  "
  (: history :push)
  ;; hs.grid.resizeWindowShorter/Taller/Thinner/Wider
  (grid :resizeWindow (. arrow-map arrow :resize)))

(fn resize-left
  []
  (resize-window :h))

(fn resize-up
  []
  (resize-window :j))

(fn resize-down
  []
  (resize-window :k))

(fn resize-right
  []
  (resize-window :l))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Move to screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn move-screen
  [method]
  "
  Moves a window to the display in the specified direction
  :north ^  :south v :east -> :west <-
  Takes a method name of the hammer spoon window instance.
  You probably will not be using this function directly.
  Performs a side effect that will move a window the next screen in specified
  direction.
  Returns nil
  "
  (let [window (hs.window.focusedWindow)]
    (: window method nil true)))

(fn move-north
  []
  (move-screen :moveOneScreenNorth))

(fn move-south
  []
  (move-screen :moveOneScreenSouth))

(fn move-east
  []
  (move-screen :moveOneScreenEast))

(fn move-west
  []
  (move-screen :moveOneScreenWest))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn init
  [config]
  "
  Initializes the windows module
  Performs side effects:
  - Set grid margins from config.fnl like {:grid {:margins [10 10]}}
  - Set the grid dimensions from config.fnl like {:grid {:size \"3x2\"}}
  "
  (hs.grid.setMargins (or (get-in [:grid :margins] config) [0 0]))
  (hs.grid.setGrid (or (get-in [:grid :size] config) "3x2")))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{:init                    init
 :activate-app            activate-app
 :center-window-frame     center-window-frame
 :highlight-active-window highlight-active-window
 :jump                    jump
 :jump-to-last-window     jump-to-last-window
 :jump-window-left        jump-window-left
 :jump-window-above       jump-window-above
 :jump-window-below       jump-window-below
 :jump-window-right       jump-window-right
 :maximize-window-frame   maximize-window-frame
 :move-east               move-east
 :move-north              move-north
 :move-south              move-south
 :move-west               move-west
 :rect                    rect
 :resize-half-bottom      resize-half-bottom
 :resize-half-left        resize-half-left
 :resize-half-right       resize-half-right
 :resize-half-top         resize-half-top
 :resize-inc-left         resize-inc-left
 :resize-inc-bottom       resize-inc-bottom
 :resize-inc-top          resize-inc-top
 :resize-inc-right        resize-inc-right
 :resize-left             resize-left
 :resize-up               resize-up
 :resize-down             resize-down
 :resize-right            resize-right
 :set-mouse-cursor-at     set-mouse-cursor-at
 :show-grid               show-grid
 :undo-action             undo}
