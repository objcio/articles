Here’s the rough outline of the article on Behaviours (Decided it's better suited name than Intentions or Controllers), how to leverage Interface Builder to simplify implementing application behaviours and have cross-project shared base of behaviours. 

Feedback is welcome :]

- [ ] What can we describe as Behaviour?
    - Introduce the idea.
    - Explain reasoning behind it.
- [ ] What benefits does Behaviour bring?
    - Simplifying view controllers code.
			- Sharing behaviours across different applications.
			- Dependency free objects
			- Allowing non-dev people to modify application.
- [ ] How one can build flexible Behaviour's?
    - Reversing lifetime ownership to avoid VC of explicitly knowing about applied behaviours.
    - Ability to make Behaviour post events.
- [ ] Examples of basic Behaviours
    - Parallax/Position animations.
			- Image picking.
			- Storyboard/XIB jumping.
- [ ] More advanced stuff
    - How to deal with delegates by using multiplexer proxy.
- [ ] Conclusion
