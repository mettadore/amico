require 'spec_helper'

describe Amico::Relationships do
  describe '#follow' do
    it 'should allow you to follow' do
      Amico.follow(1, 11)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:1").should be(1)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.followers_key}:11").should be(1)
    end

    it 'should not allow you to follow yourself' do
      Amico.follow(1, 1)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:1").should be(0)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.followers_key}:1").should be(0)
    end

    it 'should add each individual to the reciprocated set if you both follow each other' do
      Amico.follow(1, 11)
      Amico.follow(11, 1)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.reciprocated_key}:1").should be(1)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.reciprocated_key}:11").should be(1)
    end
  end

  describe '#unfollow' do
    it 'should allow you to unfollow' do
      Amico.follow(1, 11)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:1").should be(1)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.followers_key}:11").should be(1)

      Amico.unfollow(1, 11)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:1").should be(0)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.followers_key}:11").should be(0)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.reciprocated_key}:1").should be(0)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.reciprocated_key}:11").should be(0)
    end
  end

  describe '#block' do
    it 'should allow you to block someone following you' do
      Amico.follow(11, 1)
      Amico.block(1, 11)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:11").should be(0) 
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.blocked_key}:1").should be(1) 
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.reciprocated_key}:1").should be(0)
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.reciprocated_key}:11").should be(0)
    end

    it 'should allow you to block someone who is not following you' do
      Amico.block(1, 11)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:11").should be(0) 
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.blocked_key}:1").should be(1) 
    end

    it 'should not allow someone you have blocked to follow you' do
      Amico.block(1, 11)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:11").should be(0) 
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.blocked_key}:1").should be(1) 

      Amico.follow(11, 1)

      Amico.redis.zcard("#{Amico.namespace}:#{Amico.following_key}:11").should be(0) 
      Amico.redis.zcard("#{Amico.namespace}:#{Amico.blocked_key}:1").should be(1) 
    end

    it 'should not allow you to block yourself' do
      Amico.block(1, 1)
      Amico.blocked?(1, 1).should be_false
    end
  end

  describe '#unblock' do
    it 'should allow you to unblock someone you have blocked' do
      Amico.block(1, 11)
      Amico.blocked?(1, 11).should be_true
      Amico.unblock(1, 11)
      Amico.blocked?(1, 11).should be_false      
    end
  end

  describe '#following?' do
    it 'should return that you are following' do
      Amico.follow(1, 11)
      Amico.following?(1, 11).should be_true
      Amico.following?(11, 1).should be_false

      Amico.follow(11, 1)
      Amico.following?(11, 1).should be_true
    end
  end

  describe '#follower?' do
    it 'should return that you are being followed' do
      Amico.follow(1, 11)
      Amico.follower?(11, 1).should be_true
      Amico.follower?(1,11).should be_false

      Amico.follow(11, 1)
      Amico.follower?(1,11).should be_true
    end
  end

  describe '#blocked?' do
    it 'should return that someone is being blocked' do
      Amico.block(1, 11)
      Amico.blocked?(1, 11).should be_true
      Amico.following?(11, 1).should be_false
    end
  end

  describe '#reciprocated?' do
    it 'should return true if both individuals are following each other' do
      Amico.follow(1, 11)
      Amico.follow(11, 1)
      Amico.reciprocated?(1, 11).should be_true
    end

    it 'should return false if both individuals are not following each other' do
      Amico.follow(1, 11)
      Amico.reciprocated?(1, 11).should be_false
    end
  end

  describe '#following' do
    it 'should return the correct list' do
      Amico.follow(1, 11)
      Amico.follow(1, 12)
      Amico.following(1).should eql(["12", "11"])
      Amico.following(1, :page => 5).should eql(["12", "11"])
    end

    it 'should page correctly' do
      add_reciprocal_followers
      
      Amico.following(1, :page => 1, :page_size => 5).size.should be(5)
      Amico.following(1, :page => 1, :page_size => 10).size.should be(10)
      Amico.following(1, :page => 1, :page_size => 26).size.should be(25)
    end
  end

  describe '#followers' do
    it 'should return the correct list' do
      Amico.follow(1, 11)
      Amico.follow(2, 11)
      Amico.followers(11).should eql(["2", "1"])
      Amico.followers(11, :page => 5).should eql(["2", "1"])
    end

    it 'should page correctly' do
      add_reciprocal_followers

      Amico.followers(1, :page => 1, :page_size => 5).size.should be(5)
      Amico.followers(1, :page => 1, :page_size => 10).size.should be(10)
      Amico.followers(1, :page => 1, :page_size => 26).size.should be(25)
    end
  end

  describe '#blocked' do
    it 'should return the correct list' do
      Amico.block(1, 11)
      Amico.block(1, 12)
      Amico.blocked(1).should eql(["12", "11"])
      Amico.blocked(1, :page => 5).should eql(["12", "11"])
    end

    it 'should page correctly' do
      add_reciprocal_followers(26, true)

      Amico.blocked(1, :page => 1, :page_size => 5).size.should be(5)
      Amico.blocked(1, :page => 1, :page_size => 10).size.should be(10)
      Amico.blocked(1, :page => 1, :page_size => 26).size.should be(25)
    end
  end

  describe '#reciprocated' do
    it 'should return the correct list' do
      Amico.follow(1, 11)
      Amico.follow(11, 1)
      Amico.reciprocated(1).should eql(["11"])
      Amico.reciprocated(11).should eql(["1"])
    end

    it 'should page correctly' do
      add_reciprocal_followers

      Amico.reciprocated(1, :page => 1, :page_size => 5).size.should be(5)
      Amico.reciprocated(1, :page => 1, :page_size => 10).size.should be(10)
      Amico.reciprocated(1, :page => 1, :page_size => 26).size.should be(25)
    end
  end

  describe '#following_count' do
    it 'should return the correct count' do
      Amico.follow(1, 11)
      Amico.following_count(1).should be(1)
    end
  end

  describe '#followers_count' do
    it 'should return the correct count' do
      Amico.follow(1, 11)
      Amico.followers_count(11).should be(1)
    end
  end

  describe '#blocked_count' do
    it 'should return the correct count' do
      Amico.block(1, 11)
      Amico.blocked_count(1).should be(1)
    end
  end

  describe '#reciprocated_count' do
    it 'should return the correct count' do
      Amico.follow(1, 11)
      Amico.follow(11, 1)
      Amico.follow(1, 12)
      Amico.follow(12, 1)
      Amico.follow(1, 13)
      Amico.reciprocated_count(1).should be(2)
    end
  end

  describe '#following_page_count' do
    it 'should return the correct count' do
      add_reciprocal_followers

      Amico.following_page_count(1).should be(1)
      Amico.following_page_count(1, 10).should be(3)
      Amico.following_page_count(1, 5).should be(5)
    end
  end

  describe '#followers_page_count' do
    it 'should return the correct count' do
      add_reciprocal_followers

      Amico.followers_page_count(1).should be(1)
      Amico.followers_page_count(1, 10).should be(3)
      Amico.followers_page_count(1, 5).should be(5)
    end
  end

  describe '#blocked_page_count' do
    it 'should return the correct count' do
      add_reciprocal_followers(26, true)

      Amico.blocked_page_count(1).should be(1)
      Amico.blocked_page_count(1, 10).should be(3)
      Amico.blocked_page_count(1, 5).should be(5)
    end
  end

  describe '#reciprocated_page_count' do
    it 'should return the correct count' do
      add_reciprocal_followers

      Amico.reciprocated_page_count(1).should be(1)
      Amico.reciprocated_page_count(1, 10).should be(3)
      Amico.reciprocated_page_count(1, 5).should be(5)
    end
  end

  private

  def add_reciprocal_followers(count = 26, block_relationship = false)
    1.upto(count) do |outer_index|
      1.upto(count) do |inner_index|
        if outer_index != inner_index
          Amico.follow(outer_index, inner_index + 1000)
          Amico.follow(inner_index + 1000, outer_index)
          if block_relationship
            Amico.block(outer_index, inner_index + 1000)
            Amico.block(inner_index + 1000, outer_index)
          end
        end
      end
    end
  end
end