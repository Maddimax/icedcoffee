IcedCoffee
==========

IcedCoffee is a lightweight framework for building stunning user interfaces based on OpenGL ES 2.
It is written in Objective-C and runs on iOS and Mac OS X.

IcedCoffee is designed to be clean, minimalistic, consistent and reusable for different purposes.
Its main focus is on user interfaces in the context of games, but of course you may use it for
all kinds of rich and dynamic application frontends.

IcedCoffee is open source and free for both non-commercial and commercial use (MIT license.)


Getting Started
---------------

1. Download the code from github

2. Run the 'install-templates.sh' script

3. Open Xcode -> New -> New Project -> IcedCoffee


Main Features
-------------

  * Minimalistic scene graph: scene node infrastructure with arbitrary 3D transforms,
	  easily extensible via encapsulated node visitation
  * Full event handling support for nodes (touch, mouse, keyboard, motion), responder
    chain design similar to that found in Cocoa/CocoaTouch    
  * Shader-based picking/selection of nodes (support for arbitrary picking shapes)
  * Render to texture, picking through (potentially nested) texture FBOs
  * Texture loading on separate thread via GCD
  * Rendering via display link thread
  * Retina display support for all suitable devices
  * View/view controller architecture basis for easy integration with Cocoa/CocoaTouch
  * Minimalistic design with little dependencies: very easy to integrate into existing
    OpenGL and non-OpenGL applications


Copyright and License
---------------------

Copyright 2012 Tobias Lensing
Licensed under an MIT license (see LICENSE_icedcoffee.txt for details.)


Third-party Sources
-------------------

  * Portions of cocos2d's source code have been reused/refactored (see respective
	  header files and LICENSE_cocos2d.txt for details.)
  * The Kazmath project has been included to provide math structures and
	  routines for IcedCoffee's linear algebra (see LICENSE_Kazmath.txt.)
  * Creative Commons licensed images have been reused for demo purposes (see
	  the respective license files in resource folders.)