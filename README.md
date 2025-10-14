# Simple Cards V2
This project is a complete rewrite of the SimpleCards plugin I made a while back. Due to my lack of knowledge and experience, the first version lacked the quality I wanted to deliver. 

You can still check the first version here ...

## What is SimpleCards?
This is a card system plugin, made in Godot 4.5 only using UI elements (Control nodes). Because of that, the cards can be used in both 2d and 3d projects.

### Main features

**Cards** with implemented press and drag & drop functionality.

Customizable and expendable functionality and visuals provided by **layouts** and **resources**. 

Management provided by **deck** and **hand** containers. 

### Installation

#### Addon (soon™)
1. Install the addon from the Godot asset library
2. Go to Project/Project Settings/Plugins and enable SimpleCards plugin
#### Manual
1. Download or clone the repo.
2. Open it as a godot project or copy the addons/simple_cards folder into the project you want to use.
3. Go to Project/Project Settings/Plugins and enable SimpleCards plugin


## Usage and features. 
**All custom classes added are documented in the editor.**
If curios you can always check the scripts as well.

### Making your first card. 

#### 1. Making the resource. 
**Card Resource** is the way to store the data you want your card to have.

In the file manger create a script that extends CardResource. 

Give it a fancy name and class_name.

Now add everything your card needs. 

And you're done!

#### 2. Making a layout.
**Card layout** is the base of the visuals. 

Go to "Project/Tools/Create a new card layout". This will create the default template scene of a layout.

Give it a name (ex. test_layout.tscn). **This name will be used as a key in the scripts. keep it simple and/or memorable.**

**The scene will be placed in the "card_layouts" folder that will be automatically created. Any layout outside this folder will NOT be read. To change the folder go to the card_globals.gd and change the LAYOUT_FOLDER path to the you want.**

Now you can create your perfect card. **The Subview's size will determine the size of the card.**

To update the visuals, extend the card layer (the root) script. Here overwrite the: 
```
_update_display()
```
to set you changes.  You can also overwrite:
```
_flip_in()
 or
_flip_out()
```
to create transition effects for layouts.

you also have access to the **Card** and its **Resource** as card_instance and card_resource respectively. **This are set after the ready function, if trying to access in ready they will return null or might just crash :)**

After you are done you just need to set the layout to the cards:
1. use the set_layout("name", true) function in the card.
2.  set def_front_layout value from the card globals to the value you need.
3. (not recommended) replace DEFAULT_LAYOUT constant path in the global script
4.  use the custom_layout export on the resource to have per resource layout.


The cards also have a back_layout implemented, simmilar you can use this methods to set it:
1. use the set_layout("back_name", false) function in the card.
2.  set def_back_layout value from the card globals to the value you need.
3.  (not recommended) replace DEFAULT_BACK_LAYOUT constant path in the global script

#### 3. Spawning the card. 
To spawn a specific card, initialize it by passing a card_resource in the Card.new() function. 
You can also you the "Add child node" button in the editor to add a new card and manually set its resource within the editor. 

And you're done. Enjoy your card :)

### Classes

**Check the editor documentation for full details for each class and function**

#### Card
The Card is  a modified button.
On button_down the card will wait for 2 possibilities:
- If button_up is called (button released) than the click action happens. card_clicked is emited.
- If the cursor is moved pass the threshold card enters in holding state. holding = true and will follow cursor until button_up is called.
Disabling the button will stop both of this to stop working.
Setting undraggable to true will disable the draging function but not the click

#### CardResource
Abstract class used to store data. Does nothing unless extended.

The custom_layout_name export will set the front layout to the value if valid.


#### CardLayout
Node used to create visuals for the cards. Check [[#Making your first card.]] for details.

#### CardDeck
Resource class to used to store premade arrays of card_resources.
You can give it a name.

#### CardDeckManager
Takes a card deck and converts the resources into card instances. It is split in to nodes: 
draw pile and discard pile. Has basic functions like draw, discard, and shuffle. 

#### CardHand
Container node used to arrange cards in a specific shape. 
The shapes implemented for now are: 
- Arc
- Line
Use the add and remove card functions to manage the cards in the hand. 

The handle_clicked_card function also connects to the card_clicked signals of all the cards in the hand. Overwrite it to implement your own functionality.


### Example

#### Balatro Style
In the example folder there is a simple stripped down implementation of the game balatro. Use it as a refrence for what could be done :)

#### More soon™



## Have fun 
For any feedback, suggestions or complains, feel free to dm me at @twdoortoo on Twitter (formerly known as X)
