layout: post
title: Testing bad practices
category: "15"
date: "2014-08-02 09:00:00"
author: "<a href=\"http://twitter.com/luisobo/">Luis Solano</a>"
tags: article
---

I've been writing automated tests for a few years now and I have to
confess that is a technique that still fascinates me when it comes down
to make a code base more maintainable. I'd like to share some of my experiences
and lessons I've learn from others or found by myself.

After all these years I've heard many good (and bad) reasons to write
automated tests, things like:

- Making refactoring easier.
- Avoiding regressions.
- Providing an executable specification and documentation.
- Reducing costs of creating software.
- Reducing time of creating software.

Sure, you could say those are true but I want to give another
perspective to all those reasons, a unifed perspective if you will:

> The only reason automated tests are valuable is to allow us to modify
  our own code later on.

In other words:

> The only time test will give value back is when we want to _change_ our code.

Let's see how the classic arguments in favor of writing tests are connected
with this premise:

- Makes refactoring easier: you can change implementation details
  with confidence leaving the public API untouched.
- Avoids regressions: When do regressions occur? When you change your
  code.
- Executeble specification and documentation: When do you want to
  know more about how software actually works? When you want to modify
it.
- Reduces time of creating software: How? By allowing you to modify your
  code faster, confident that your tests will tell you when something
went wrong.
- Reduces cost of creating software: Well, time is money.

Yes, all the reasons above are true down the road but the reason that
pertains to us, developers, is that automated tests let us change stuff.

Note that I'm not including the design feedback of _writing_ tests, as in TDD. That
could be a separate conversation. We will be talking about tests, once they are written.

Seems then that writing test and _how_ to write them should be motiviated by _change_.

An easy way to take into account this fact when writing a test is to always ask your tests these two
questions:
- "Are you going to fail (or pass) if I change my production code?"
- "Is that a good reason for you to fail (or pass)?"

If you find a bad reason for your test to fail (or pass), fix it.

That way when we change our code later down the road our tests will pass or fail only
for good reasons giving us a better return that flakly tests that fail for the wrong reason.

What's the big deal about that? You may ask.

Let's answer this with another question: Why do our tests break when we
change our code?

We agreed that the the main purpose of having tests is so we can change our code with ease
Then, how are all those red tests helping us? Those failing tests are nothing but noise, an
impediment to get the job done so, how do we do it?

It depends on the reason why we are changing the code:

### Changing the behavior of the code

The starting point should always be green, i.e. all tests should pass.

If you want to change your code to change its behavior (i.e. changing what
your code _does_) you would:

1. Find the test or tests that define the current behavior that you want to
  change.
1. Modify those tests to expect the new desired behavior.
1. Run the tests and see those modified tests fail.
1. Update your code to make all tests pass again.

At the end of this process we are back at square one -- all tests pass
and we are ready to start over if needed.

Because you know exactly which tests failed and which modification of the
code made them pass you are confident that you only changed what you
wanted to change. This is how automated tests help us modify our code,
in this case to change its behavior.

In this case is okay to see a test failing, but only the tests related to the
behvior that we are updating.


### Refactoring: changing the implementation of the code, leaving the behavior intact

Again, the starting point should always be a green.

If all you want is to change the implementation of a piece of code to
make it simpler, more performant, easy to extend, etc (i.e. changing
_how_ your code does it but not _what_ it does) this is the extensive
list of steps to follow:

1. Modify your code without touching your tests at all.

Once your code is simpler, faster or more flexible your tests should stay
just as they started -- green, and they should have only fail in case
you did something wrong while refactoring, mistake that you quickly
reverted getting the tests back to green.

Because your tests stayed green the whole time you know that you didn't break
anything. That's how automated tests let us modify our code, refactoring
it in this case.

In this case it is not okay to see a test failing. It could mean that:
- We accidentally changed the external behavior of the code. Good, our tests are helping us.
- We didn't change the external behavoir of the code. Bad, we got false negatives. This is where most of the trouble is.


We want our tests to aid in the processes described above. Let's see  some DOs
 and DON'Ts that will help making our tests more cooperative.

## Good practices 101

Before jumping into how _not_ to write your tests I'd like to go over the
a few good practices really quick. There are 5 basic rules that every test should obey
to be consider a good – or even a _valid_ – test. There is a mnemonic for
these 5 rules: F.I.R.S.T. Tests should be:

- **F**ast: so we can execute them often
- **I**solated: one test cannot depend from external factors or from the result of another test.
- **R**epeatable: tests should have the same result every time we run them.
- **S**elf-verifying: test should include assertions. No human intervention needed.
- **T**imely: test should be written along with the production code.

To know more about these set of rules you can read [this article](http://pragprog.com/magazines/2012-01/unit-tests-are-first) by Tim Ottinger, Jeff Langr


## Bad practices

How do we maximize the outcome of our tests? In one sentece

> Don't couple your tests to implementation details.

### Don't test private methods

[](http://shoulditestprivatemethods.com) nuff' said.

Private means private. Period. If you feel the need to test a private
method there is something wrong conceptually with that method. Usually
it is doing too much to be a private method, violating the [Single Responsibilty Principle](http://www.objectmentor.com/resources/articles/srp.pdf)

Today:
Your class has a private method, it does planty of stuff so you decide to
test it.
You make that method public, just for testing purposes, even though it
makes no sense to use that method on it's own, it's only meant to be used
internally by other public methods of the same class.
You write tests for that private (now techinically public method)

Tomorrow:
You decide to modify what this method does because some change in the
requirements (totally fine)
You find out that some coworker is using that method from another class,
for something totally differnt because "it does want I need". After all
it was public, right?
This private method is not part of the public API.
You cannot modify this method without breaking your collegue's code.

What to do: extract that private method to a separate class, give that
class a properly defined contract and test it separately.
When testing code that relies on this new class you can provide a test double
of that class if needed.

So, how do I test my private methods? Via the public API of that class.
Always test your code via its public API. The public API of you code
defines a contract, a well define set of expectations about how your
code is going to act based on different inputs. The private API (private
methods or even entire classes) does not define that contract and it is
subject to change without notice, therefore your tests (or your colleagues)
cannot rely on them.

By doing this you will remaing free to change your (truly) private
code and the design of your code will improve by having smaller classes
that do one thing and are properly tested.

### Don't stub private methods

It has all the same caveats as exposing a private method for testing but on top
of that it could be hard to debug. Usually stubbing libraries rely on hacks to
get the job done making it hard to find out why a test is failing.

Also, when we stub a method we should doing it accordingly to its contract
but a private method has no specified contract, that's mostly why it's
private after all. Since the behavior of a private method is subject of
change without notice your stub may diverge from reallity but your test
_will still pass_. Horrendous. Let's see an example:

Today:
Public method of a class relies on a private method of the same class.
Private method foo never returns nil.
Tests for the public method stub out the private method, for convenience.
When stubbing out method foo you never consider making foo return nil
because currently it never happens.

Tomorrow:
The private method changes and now it returns nil. It's a private method
so it's fine thing to do.
Tests of public method are never updated accordingly ("I'm changing a private method,
why should I update any test at all?")
The public method is now broken for the case where the private method returns
nil but the tests still pass!

Horrendous.

What to do: since foo is doing too much, extract that method to a new
class and test it separately. Then, when testing bar, provide a test
double for that new class.

### Don't stub external libraries

Third-party code should never be mentioned direclty in your tests.

Today:
Your networking code relies on the famous HTTP library LSNetworking
To avoid hitting the actual network (to make your tests fast and reliable)
you stub out the method `-[LSNetworking makeGETrequest:]` of that library,
properly replacing its behavior (it calls the success callback with a
canned response) but without hitting the network.

Tomorrow:
You need to swap LSNetworking with an alternative (It could be that
LSNetworking is no longer maintaineid or you need to switch
to a more advance library because it has that feature that you need,
whatever).
It's a refactor so you should not change your tests.
You replace the library.
Your tests fail because the dependency of the network is no longer being
stubbed (`-[LSNetworking makeGETrequest:]` is no longer being call by
the implementation)

What to do: Rely on umbrella stubbing to replace the entiry
functionality of that library during tests.

Umbrella stubbing (a term that I just made up) consist of stubbing out
all the possible ways that your code may use, now and in the future, to get
some task done, via a declarative API, agnostic to any implementation
detail.

Like in the example above, your code can rely on "HTTP library A" today
but there are other possible ways of making an HTTP request, right? like
"HTTP library B".

As an example, one solution that provides umbrella stubbing for
networking code is my open source project [Nocilla](https://github.com/luisobo/Nocilla).
With [Nocilla](https://github.com/luisobo/Nocilla) you can stub HTTP
requests in a declarative fashion, without mentioning any HTTP library.
[Nocilla](https://github.com/luisobo/Nocilla) takes care of stubbing any HTTP library out there so you don't couple
your tests to any implemenation detail, allowing you to switch your
networking stack without breaking your tests.

Another example could be stubbing out dates. There are many ways of
getting the current time in most programming languages but libraries like
[TUDelorean](https://github.com/tuenti/TUDelorean) take care of stubbing
every single time-related API so you can control "what time is it" for
testing purposes without coupling your tests to any of those multiple
time APIs, letting you to refactor your implementation to a different
time API without breaking your tests.

In realms other than HTTP or dates, where a variety of APIs may be
available, you can use similar solutions to do
umbrella stubbing or you can create your own open source solution and
share it with the community so the rest of us can properly write test.


### If you stub out a dependency do it properly

This goes in hand with the previous point but this problem is more
common. When your code relies on a dependecy to get something done but
that dependecy provides may way of getting the same thing done
but you only stubbed a subset of all those ways.

In this case there are no other third party alternatives to get the job
done but the dependency of your code provides multiple ways of doing
the same thing.

Today:
The class UsersController relies on the class UsersRepository to
retrieve users from the database.
You are testing UsersController and you stub out the `find` method of the
UsersRepository class to make your tests run faster and in a determisnistic
fashion, which is an awesome thing to do.

Tomorrow:
You decide to refactor UsersController to use the new query syntax of
UsersRepository, which is more readable.
Because it's a refactoring you should not touch your tests.
You update UsersController to use the more readable method `where` to find the
records of interest.
Now your tests are broken because they stub the method `find` but not
where.

Umbrella stubbing can help here in some cases but for our case
with the class UsersController... well, there is no alternative library to
fetch _my_ Users from _my_ database.

What to do: create an alternative implementation of the same
class for testing purposes and use it as a test double.

To continue with our example we should provide an InMemoryUsersReposity.
This in-memory alternative should comply to every single aspect of the
contract stablished by the original class UsersRepository, except that
it stores data in-memory to make our tests fast. This means that when
you refactor UsersRepository  you do the same with its in-memory version.
To make it very clear: yes, you now have to maintain two different
implementations of the same class.

You can now provide this lightweight version of your dependency as a test
double. The good thing is it's a full implementation so, when you decide
to move your implementation  from one method to the other (from `find`
to `where` in our example) the test double being used will already
support that new method and your tests won't fail when you refactor.

There is nothing wrong maintaining another version of your class and, in
my experience, it ends up being very little effort and it definitely pays off.

Just like CoreData does with its InMemory version of the stack,
you can also provide your lightweight version of your class as part of the
production code, it could be of some use to someone.


### Don't test constructors

Constructors are implementation details by definition and, since we
agreed that we should decouple our tests from implementation details,
you should not test constructors.

Furthermore, constructors should have no behavior and, since we agree
that we should only test the behavior of our code, there is nothing to
test so you should no test constructors.

Today:
Your class Car has one constructor.
You test that, once a Car is constructed, it's engine is not nil (because you
know that the constructor creates a new Engine and assigns it to the
variable `_engine`)

Tomorrow:
The class Engine turns out to be costly to construct so you decide to
lazy initialize it the first time that the getter of Engine is called.
(Totally fine thing to do).
Your test for the constructor of the class Car breaks because, upon
construction, Car has no longer an Engine, even though the Car will
perfectly work.
Another option is that you test does not fail because testing that the
car has an Engine triggers the lazy load initialization of the Engine,
so my question is, what are you testing again?

What to do: test how the public API of you class behaves when
constructing it in different ways. A silly example: Test how the method
`count` of the class list behaves when the list is constructed with and
without items. Just note that you are testing the behavior of `count`
and not the behavior of the constructor.

In case that your class has more than one constructor consider it a
smell. Your class may be doing to much. Try to split it in smaller
classes but if there is a legitimate reason for your class to have
multiple constructors just follow the same piece of advice, make sure
you test the public API of that class constructing it in different ways,
in this case, using every constructors. (i.e. when this class is in this
initial state, it behaves like this. When it's in this other initial
state it behaves like that).

## Conclusion

Writing tests is an investment – we need to put time in the form of writing
and maintaining them. The only way to justify such investment is because
we expect to get that time back. Coupling tests to implementation details will
reduce the amount of value that our tests will provide, making that investment
less worthwhile or even worthless in some cases.

When writing tests step back and ask yourself if those tests will maximize the
outcome of your investment by checking if your tests could fail or pass for the
wrong reason, either when refactoring or when changing the behavior of the system.
