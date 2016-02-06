{expect} = require "chai"
utils = require "../utils"
fixtures = require "./fixtures/object"

base = utils.require "base"
{Collections} = base
HasProps = utils.require "core/has_props"
{Document} = utils.require "document"

describe "has_properties module", ->
  before ->
    fixtures.Collection.reset()
    base.collection_overrides['TestObject'] = fixtures.Collection
  after ->
    base.collection_overrides['TestObject'] = undefined

  it "should support computed properties", ->
    model = Collections('TestObject').create({'a': 1, 'b': 1})
    model.register_property 'c', ->
      @get('a') + @get('b')
    model.add_dependencies('c', model, ['a', 'b'])

    expect(model.get "c").to.equal 2

  describe "cached properties", ->
    model = null
    before ->
      model = Collections('TestObject').create({a: 1, b: 1})
      model.register_property 'c', ->
          @get('a') + @get('b')
        , true
      model.add_dependencies('c', model, ['a', 'b'])

    it "should be computed", ->
      expect(model.get "c").to.equal(2)

    it "should store computed values in cache", ->
      expect(model._computed["c"].cache).to.not.be.undefined

    it "should invalidate cached values on changes", ->
      model.set('a', 10)

      expect(model.get "c").to.equal(11)

  describe "arrays of references", ->
    [model1, model2, model3, model4, doc] = [null, null, null, null, null]
    before ->
      model1 = Collections('TestObject').create({a: 1, b: 1})
      model2 = Collections('TestObject').create({a: 2, b: 2})
      model3 = Collections('TestObject').create(
        a: 1
        b: 1
        vectordata: [model1.ref(), model2.ref()]
      )
      model4 = Collections('TestObject').create(
        a: 1
        b: 1
        vectordata: [[model1.ref(), model2.ref()]]
      )

      # resolving refs should only work if we're in a document
      # (really, we should probably simply not put refs in an array
      # outside of while deserializing a document...
      # not sure the real code ever does this anymore, we may
      # be able to delete resolve_ref and delete these tests)
      doc = new Document()
      doc.add_root(model1)
      doc.add_root(model2)
      doc.add_root(model3)
      doc.add_root(model4)

    it "should dereference elements by default if inside a document", ->
      expect(model3.document).to.equal doc
      output = model3.get('vectordata')

      expect(output[0].document).to.equal doc
      expect(output[1].document).to.equal doc
      expect(output[0]).to.equal model1
      expect(output[1]).to.equal model2

    it "should work with nested arrays", ->
      expect(model4.document).to.equal doc
      output = model4.get('vectordata')

      expect(output[0][0].document).to.equal doc
      expect(output[0][1].document).to.equal doc
      expect(output[0][0]).to.equal model1
      expect(output[0][1]).to.equal model2
