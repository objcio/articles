TextEdit

This directory contains the source code for the TextEdit application. TextEdit is a simple text editor based on the NSText and NSDocument subsystems of Cocoa.

Major source files and what's interesting about them:

Document.m

Subclass of NSDocument.  One instance of this is created for every document (new or saved) in TextEdit.  

The text contents (characters, attachments, attributes) of the document are kept in an instance of NSTextStorage. 

Document overrides readFromURL:ofType:error: since it wants to specify the user options for opening files, such as encoding and whether to open rich text documents as plain.  These come from DocumentController, who hangs on to the values chosen by the user when the open panel was displayed.  The main reading workhorse is readFromURL:ofType:encoding:ignoreRTF:ignoreHTML:error:, which does a bunch of text-specific stuff to load the document with specified options.

Document also overrides writeToURL:ofType:error: since it wants more control over the writing process.  However it will sometimes invoke the NSDocument version of this method by calling super, and to support that there is an override of fileWrapperOfType:error: as well.

Note that even with these customizations, TextEdit is able to benefit from many of NSDocument's built-in saving features, such as its ability to track documents on disk after renaming, safe-saving, hidden extension handling, autosaving for recovery purposes, etc...

Document hangs on to a number of properties, such as the scaleFactor, viewSize, readOnly, backgroundColor, hyphenationFactor, etc. These are kept up to date with user's choices by various methods, and written out to rich text documents when saving.

There are also document properties that are settable by the user, such as author, company, keywords, ... These are stored in instance variables in Document and updated via bindings from the document properties panel.  Like other properties, these are also written out with rich text documents.

In order to enable these properties to be undoable, Document implements setValue:forDocumentProperty:.  This is called from the standard KVC method setValue:forKey: for properties we want to be undoable. By registering setValue:forDocumentProperty: as the callback in NSUndoManager, we workaround the NSUndoManager bug where prepareWithInvocationTarget: fails to freeze-dry invocations with "known" methods such as setValue:forKey:.

Note the "trick"  of providing string localizations in comments as a way to get genstrings to pick up the localizations when there are actually no 
explicit corresponding calls to NSLocalizedString and variants in the code. This allows us to provide menu titles for changes to document properties.  (Search for "For genstrings".)

Override of printOperationWithSettings:error: enables TextEdit to customize its printing by first making sure the text for the whole document is laid out before printing, and by adding an print accessory view to control whether pages should be numbered or not.

In the printInfo for the document, TextEdit sets horizontal pagination to NSFitPagination. This allows the text to be printed with the same wrapping as on the screen. In "wrap-to-window" mode this means the text might need to be scaled smaller when printed.  This behavior should really be controlled by a check box in the TextEdit accessory on print panel, but this hasn't happened yet.

As you will note, there is a good deal of code to deal with encoding of the characters in the document when the document contains plain text. The instance variable documentEncoding stores the encoding of the document; this is either deduced from the file or specified by the user when the document is opened. Keeping this encoding around allows the document to be saved with the same encoding as it was read. (When in memory the character encoding of the document is somewhat meaningless, because the characters in the document are stored in an NSString, whose backing stores are always expressed in terms of Unicode characters. The encoding determines how to save the document when saved as plain text.)


DocumentWindowController.m

Subclass of NSWindowController for managing the Document class's interaction with its document window and views.

DocumentWindowController is responsible for creating the NSLayoutManager and one or more NSTextViews (depending on whether "wrap to page" mode is selected). These provide the UI layer for the text backing, which is stored in the Document class.

DocumentWindowController establishes a number of connections:

It observes the printInfo, richText, viewSize, and hasMultiplePages properties of the document.  When it gets told these are changed (in observeValueForKeyPath:ofObject:change:context:, it updates the window or view as appropriate.

It observes the backgroundColor of the text view and scaleFactor of the scrollView, communicating any changes in these to the document. (These properties are changed directly in the view by the user.)

DocumentWindowController binds its layout manager's hyphenationFactor to document.hyphenationFactor,  and text view's editable to document.readOnly (through a negating value transformer). These allow reflecting changes from these in UI without any intermediate glue code.

setHasMultiplePages: determines whether the document is in wrap-to-page mode or not; study this method, addPage, and removePage to see how to create and manipulate NSTextViews programmatically.

The method textEditDoForegroundLayoutToCharacterIndex: shows how to get the text system to lay text out in the foreground up to a certain character location. By default the text system does its layout in the background, which allows bringing up the window fairly quickly. The user can even edit, print, or save the document while the background layout is going on. This method enables having the first portion of the document already laid out. Note that this was useful from a user point of view in Tiger, where the scrollbar for the document raced down the page as background layout happened, but it's less interesting in Leopard when non-contiguous background layout is enabled. However, we still do it, and this method is also ueful for when printing the document (since TextEdit doesn't rewrap or relayout when printing and just uses its existing layout into).

This class implements a number of NSTextView, NSLayoutManager, and NSWindow delegate methods.  

textView:clickedOnLink:atIndex: is overridden to allow opening links that represent text files directly in TextEdit, revealing other files in Finder, and opening non-local file URLs in the user's browser.  textView:doubleClickedOnCell:inRect:, textView:writablePasteboardTypesForCell:atIndex:, and textView:writeCell:atIndex: allow opening and copying attached documents.  

layoutManager:didCompleteLayoutForTextContainer:atEnd: controls adding/removing of pages as the document is edited or laid out.

windowWillUseStandardFrame:defaultFrame: method provides "standard" and "user" sizes for resizing (or right-sizing) the document window via the green button.

This class takes care of setting the document as non-transient after moving or resizing the window.


DocumentController.m

Subclass of NSDocumentController. Most NSDocument-based applications don't need to subclass NSDocumentController. TextEdit does this to provide "transient document" behavior, as well as customizing the open panel.

When the document controller is initialized, it binds its autosaving delay field to user defaults, in order to be automatically notified when the user changes this preference.

Transient document is the untitled document put up when TextEdit is first launched, or activated with no other documents open.  If the user makes no changes to this untitled document before opening a new document, we get rid of the untitled document and visually replace it with the opened one. NSDocument doesn't yet have support for this, hence the code in TextEdit.

The open panel customizations include an accessory view which lets the user choose whether to load rich text documents as plain, and the text encoding to be used for plain documents.  These settings are then made available (in the context of the open operation) to the Document class via the methods lastSelectedEncoding, lastSelectedIgnoreHTML, and lastSelectedIgnoreRich.


MultiplePageView.m

In wrap-to-page mode there is one NSTextView per page. MultiplePageView is the top level view which groups all of these views.  It is inserted as the document view of the scroll view in the document window. MultiplePageView is fairly simple, providing support for conversions between page numbers and rects, and drawing the background for the pages.

A possible enhancement to this class would be to have it allow the user to manipulate the page margins by dragging guides around. An advanced exercise would be to add custom markers to the ruler to allow changing the page margins via the ruler as well.


ScalingScrollView.m

Contains ScalingScrollView, a subclass of NSView to implement a scroll view with a popup to allow setting the zoom factor. This class is fairly generic and can easily be used in a variety of cases.  The scaleFactor property can be observed.

In TextEdit, this class is always in use in every document window. However, in wrap-to-window mode, the horizontal scroller and the scale popup are disabled, and the scale is set to 100%.


Preferences.m

An NSWindowController subclass that controls the preferences window. Since the switch to a bindings-based preferences window, this class has become greatly simplified. However, some preferences, such as HTML saving options and font settings, require special action and are still handled here.

The preferences controller also makes sure that the window size settings are valid; if the user enters an invalid dimension, the field is reset to its previous value.


Controller.m

This file contains the central controller object for TextEdit.  With TextEdit's move to NSDocument, and creation of several other controllers, this class has shed some weight in Leopard and has fewer responsibilities.

In its +initialize method this class registers default values for all preferences (besides fonts, which are handled directly by NSFont's facilities for "user fonts").

Controller object also provides the little support necessary for allowing TextEdit to provide the "Open File" and "Open Selection" services to other applications. All that needs to happen to support this powerful feature is an entry in the Info.plist file listing the services provided, and methods in Controller to respond to the services requests: openFile:userData:error: and openSelection:userData:error:.

Since openFile:userData:error: may be given arbitrary text as file names, it does some clean-up and extra checks. For instance, it trims whitespace and does "~" expansion (where "~" is used as a shortcut to mean "home folder"). 


EncodingManager.m

This file provides the class EncodingManager, which does most of the sophisticed text encoding related stuff.  This class also manages a panel which lets the user customize the list of encodings available in the application.

In addition, EncodingManager provides the ability to load the accessory view used in open and save panels.

The EncodingPopUpButtonCell class implements a popup which lets the user choose from a list of encodings. The list can be customized via an entry in the popup which brings up a customization panel.  The class's instances assure that they are updated (via notifications) after any change in the customization panel.


LinePanelController.m

Manages the "Select Line" panel. Subclass of NSWindowController. Uses NSScanner to parse user input.  

The beefiest code in this class is getRange:inTextView:fromLineSpec:toLineSpec:relative:, which figures out the range of characters to be selected based on user's input. Note that this input can be an absolute line (1..number of lines), an absolute range (two line numbers separated by a dash), or a relative line or range (number prefixed by plus or minus).


DocumentPropertiesPanelController.m

Manages the “Document Properties” panel. Yet another subclass of NSWindowController.

This class is an example of implementing an inspector-style panel with bindings.  It goes out of its way to take care of one area not covered automatically by the kit, namely committing of editing (that is, the user has typed a value in a field but not hit return or tab to leave the field) when the user deactivates the document window or closes the properties panel.  Since there is no validation necessary for any of the fields in this panel, always committing is a straightforward solution.

DocumentPropertiesPanelController keeps track of the current active document by observing mainWindow.windowController.document on NSApp, and updating the KVO-compliant property inspectedDocument when these are received.   

All the fields in this panel are hooked up to the inspectedDocument through an NSObjectController, using the corresponding properties in Document—author, company, keywords, etc. Any new fields can be added to the panel with no changes to this class.

DocumentPropertiesPanelController also implements the NSEditorRegistration protocol, objectDidBeginEditing: and objectDidEndEditing:. As the user starts/stops editing in the fields in the panel, these methods are invoked. DocumentPropertiesPanelController passes these straight through to the inspectedDocument. In turn NSDocument commits/discards editing as necessary when saving or closing documents.  In addition, whenever a document is deactivated, any editing in the currently edited field is committed; this is done in stopInspectingDocumentOfWindow:.

In order to commit editing when the properties panel itself is closed or deactivated, DocumentPropertiesPanelController listens to the NSWindowDidResignKeyNotification notification on the panel itself. 

Although the single instance of this class is created at launch time, none of the notifications are signed up for until the panel is brought up the first time, in windowDidLoad.  So this panel has minimal performance impact when not used.

Finally, this class implements a method to toggle the panel (if active, order it out; otherwise, activate, ordering in if necessary), and a validateMenuItem: method to update the title of the "Show Properties" menu item.

This class is mostly reusable; just the name of the class, the nib, validateMenuItem:, and reference to [Document class] need changing. It can be made into an semi-abstract NSWindowController for inspectors by removing these pieces into a subclass.


PrintPanelAccessoryController.m

A subclass of  the new NSViewController class. Used for adding an accessory view to the print panel. In the case of TextEdit, the accessory view contains just a checkbox, controlling whether or not to include headers and footers on printouts.

PrintPanelAccessoryController has a BOOL pageNumbering property to determine whether headers and footers should be included. The property is actually not stored in this class, but set directly in the printInfo, which is the representedObject.

The method keyPathsForValuesAffectingPreview is overridden to return "pageNumbering" as a way to declare that any changes to this property should update the print preview displayed in the print panel.

An override of localizedSummaryItems provides the info to be displayed in the print panel's "Summary" pane.

These two methods above are part of the NSPrintPanelAccessorizing protocol.

