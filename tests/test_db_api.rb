$LOAD_PATH[0,0] = File.join(File.dirname(__FILE__), '..', 'lib')

require 'mongo'
require 'test/unit'

# NOTE: assumes Mongo is running
class DBAPITest < Test::Unit::TestCase

  def setup
    host = ENV['HOST'] || ENV['host'] || 'localhost'
    port = ENV['PORT'] || ENV['port'] || 27017
    @db = XGen::Mongo::Driver::Mongo.new(host, port).db('ruby-mongo-test')
    @coll = @db.collection('test')
    @coll.clear
    @r1 = @coll.insert('_id' => new_oid, 'a' => 1)      # collection not created until it's used
    @coll_full_name = 'ruby-mongo-test.test'
  end

  def teardown
    @coll.clear unless @coll == nil || @db.socket.closed?
  end

  def test_clear
    assert_equal 1, @coll.count
    @coll.clear
    assert_equal 0, @coll.count
  end

  def test_insert
    @coll.insert('_id' => new_oid, 'a' => 2)
    @coll.insert('_id' => new_oid, 'b' => 3)

    assert_equal 3, @coll.count
    docs = @coll.find().collect
    assert_equal 3, docs.length
    assert docs.detect { |row| row['a'] == 1 }
    assert docs.detect { |row| row['a'] == 2 }
    assert docs.detect { |row| row['b'] == 3 }
  end
  
  def test_inserted_id
    doc = @coll.find().collect.first
    assert_equal @r1['_id'], doc['_id']
  end
  
  def test_find
    @r2 = @coll.insert('_id' => new_oid, 'a' => 2)
    @r3 = @coll.insert('_id' => new_oid, 'b' => 3)
    # Check sizes
    docs = @coll.find().map
    assert_equal 3, docs.size
    assert_equal 3, @coll.count
    # Find by id 
    docs = @coll.find('_id' => @r1['_id']).map
    assert_equal 1, docs.size
    doc = docs.first
    assert_equal doc['_id'], @r1['_id']
    assert_equal doc['a'], @r1['a']    
    # Find by id (same id again)
    docs = @coll.find('_id' => @r1['_id']).map
    assert_equal 1, docs.size
    doc = docs.first
    assert_equal doc['_id'], @r1['_id']
    assert_equal doc['a'], @r1['a']    
    # Find by other value
    docs = @coll.find('a' => @r1['a']).map
    assert_equal 1, docs.size
    doc = docs.first
    assert_equal doc['_id'], @r1['_id']
    assert_equal doc['a'], @r1['a']    
    # Find by advanced query (less than)
    docs = @coll.find('a' => { '$lt' => 10 }).map
    assert_equal 2, docs.size
    assert docs.detect { |row| row['a'] == 1 }
    assert docs.detect { |row| row['a'] == 2 }
    # Find by advanced query (greater than)
    docs = @coll.find('a' => { '$gt' => 1 }).map
    assert_equal 1, docs.size
    assert docs.detect { |row| row['a'] == 2 }
    # Find by advanced query (less than or equal to)
    docs = @coll.find('a' => { '$lte' => 1 }).map
    assert_equal 1, docs.size
    assert docs.detect { |row| row['a'] == 1 }
    # Find by advanced query (greater than or equal to)
    docs = @coll.find('a' => { '$gte' => 1 }).map
    assert_equal 2, docs.size
    assert docs.detect { |row| row['a'] == 1 }
    assert docs.detect { |row| row['a'] == 2 }
    # Find by advanced query (between)
    docs = @coll.find('a' => { '$gt' => 1, '$lt' => 3 }).map
    assert_equal 1, docs.size
    assert docs.detect { |row| row['a'] == 2 }
    # Find by advanced query (in clause)
    begin
      docs = @coll.find('a' => {'$in' => [1,2]}).map
      assert_equal 2, docs.size
      assert docs.detect { |row| row['a'] == 1 }
      assert docs.detect { |row| row['a'] == 2 }
    rescue Exception => ex
      # this currently breaks
      assert false
    end
  end
  
  def test_close
    @db.close
    assert @db.socket.closed?
    begin
      @coll.insert('a' => 1)
      fail "expected IOError exception"
    rescue IOError => ex
      assert_match /closed stream/, ex.to_s
    end
  end

  def test_drop_collection
    assert @db.drop_collection(@coll.name), "drop of collection #{@coll.name} failed"
    assert !@db.collection_names.include?(@coll_full_name)
    @coll = nil
  end

  def test_collection_names
    names = @db.collection_names
    assert names.length >= 1
    assert names.include?(@coll_full_name)

    coll2 = @db.collection('test2')
    coll2.insert('a' => 1)      # collection not created until it's used
    names = @db.collection_names
    assert names.length >= 2
    assert names.include?(@coll_full_name)
    assert names.include?('ruby-mongo-test.test2')
  ensure
    @db.drop_collection('test2')
  end

  def test_collections_info
    cursor = @db.collections_info
    rows = cursor.collect
    assert rows.length >= 1
    row = rows.detect { |r| r['name'] == @coll_full_name }
    assert_not_nil row
    assert_equal @coll.name, row['options']['create']
  end

  def test_full_coll_name
    assert_equal @coll_full_name, @db.full_coll_name(@coll.name)
  end

  def test_index_information
    @db.create_index(@coll.name, 'index_name', ['a'])
    list = @db.index_information(@coll.name)
    assert_equal 1, list.length
    info = list[0]
    assert_equal 'index_name', info[:name]
    assert_equal 1, info[:keys]['a']
  end
  
  private
  
  def new_oid
    XGen::Mongo::Driver::ObjectID.new.to_s
  end
end