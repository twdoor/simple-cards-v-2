# Functions On The Fly

![Plugin Showcase](https://raw.githubusercontent.com/NickHatBoecker/nhb_functions_on_the_fly/refs/heads/main/assets/create_function_showcase.gif)

- Easily create missing functions or get/set variables in Godot
- Shortcuts are configurable in the Editor settings
    - Under "Plugin > NHB Functions On The Fly"
- Contributors:
    - [Initial idea](https://www.reddit.com/r/godot/comments/1morndn/im_a_lazy_programmer_and_added_a_generate_code/) and get/set variable creation: [u/siwoku](https://www.reddit.com/user/siwoku/)
    - Get text under cursor, so you don't have to select the text: [u/newold25](https://www.reddit.com/user/newold25/)
    - Consider indentation type (Tabs vs Spaces) and shorcuts: [u/NickHatBoecker](https://nickhatboecker.de/linktree/)

## Create function

1. Write `my_button.pressed.connect(on_button_pressed)`
2. Select `on_button_pressed` or put cursor on it
3. Now you can either
    - Right click > "Create function"
    - <kbd>Ctrl</kbd> + <kbd>[</kbd>
    - <kbd>⌘ Command</kbd> + <kbd>[</kbd> (Mac)

## Create get/set variable

1. Write `var my_var`
2. Select `my_var` or put cursor on it
3. Now you can either
    - Right click > "Create get/set variable"
    - <kbd>Ctrl</kbd> + <kbd>'</kbd>
    - <kbd>⌘ Command</kbd> + <kbd>'</kbd> (Mac)
