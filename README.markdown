# Fake Braintree Redirect

**Test Braintree Transparent Redirect easily!**

The Fake Braintree library provides a middleware which will pretend it's
Braintree, but only for transparent redirect requests.

This library is useful for testing Braintree's Transparent Redirect feature when
you're writing Capybara tests and don't want to wait for the actual Braintree
request/response cycle to happen.

This library was originally written for inclusion within [Multitenancy with
Rails](http://leanpub.com/multi-tenancy-rails), but can also be useful outside
the concepts covered in the book.

## Installation

    gem 'fake_braintree_redirect', :github => "radar/fake_braintree_redirect"

## Usage

Typically, you have a form that looks like:

```erb
<%= form_for :transaction,
     :url => Braintree::TransparentRedirect.url,
     :html => {:autocomplete => "off"} do |f| -%>
```

If you run this test within Capybara *without using a JavaScript driver*, then
the form will make the request to your local server. Thanks Capybara!

Therefore we can insert a piece of middleware to catch that request and pretend
like we're Braintree. Put this in `spec/support/fake_braintree.rb` and make sure
it's required for your test, after Rails is loaded.

```ruby
require 'fake_braintree_redirect'
Rails.application.config.middleware.use FakeBraintreeRedirect
```
