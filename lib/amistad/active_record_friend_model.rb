require 'squeel'

module Amistad
  module ActiveRecordFriendModel
    extend ActiveSupport::Concern

    included do
      #####################################################################################
      # friendships
      #####################################################################################
      has_many  :friendships,
        :class_name => "Amistad::Friendships::#{Amistad.friendship_model}",
        :foreign_key => "friendable_id"

      has_many  :pending_invited,
        :through => :friendships,
        :source => :friend,
        :conditions => { :'friendships.pending' => true, :'friendships.blocker_id' => nil }

      has_many  :invited,
        :through => :friendships,
        :source => :friend,
        :conditions => { :'friendships.pending' => false, :'friendships.blocker_id' => nil }

      #####################################################################################
      # inverse friendships
      #####################################################################################
      has_many  :inverse_friendships,
        :class_name => "Amistad::Friendships::#{Amistad.friendship_model}",
        :foreign_key => "friend_id"

      has_many  :pending_invited_by,
        :through => :inverse_friendships,
        :source => :friendable,
        :conditions => { :'friendships.pending' => true, :'friendships.blocker_id' => nil }

      has_many  :invited_by,
        :through => :inverse_friendships,
        :source => :friendable,
        :conditions => { :'friendships.pending' => false, :'friendships.blocker_id' => nil }

      #####################################################################################
      # blocked friendships
      #####################################################################################
      has_many  :blocked_friendships,
        :class_name => "Amistad::Friendships::#{Amistad.friendship_model}",
        :foreign_key => "blocker_id"

      has_many  :blockades,
        :through => :blocked_friendships,
        :source => :friend,
        :conditions => "friend_id <> blocker_id"

      has_many  :blockades_by,
        :through => :blocked_friendships,
        :source => :friendable,
        :conditions => "friendable_id <> blocker_id"
    end

    # suggest a user to become a friend. If the operation succeeds, the method returns frienship class, else false
    def invite(user)
      return false if user == self || find_any_friendship_with(user)
      friendship = Amistad.friendship_class.new{ |f| f.friendable = self ; f.friend = user ; f.platform = 'facebook' ; f.pending = true; f.friend_registered = user.is_registered? }
      friendship.save
      return friendship
    end

    #add facebook friend
    def add_fb_friend(user, mutual_friends_count=0)
      add_friend(user, "facebook", mutual_friends_count)
    end

    def add_friend(user, platform, mutual_friends_count=0)
      return false if user == self || find_any_friendship_with(user)
      friendship = Amistad.friendship_class.new{ |f| f.friendable = self ; f.friend = user ; f.platform = platform; f.mutual_friends_count = mutual_friends_count; f.pending = false; f.friend_registered = user.is_registered? }
      frienship.save
      return friendship
    end

    # approve a friendship invitation. If the operation succeeds, the method returns friendship class, else false
    def approve(user)
      friendship = find_any_friendship_with(user)
      return false if friendship.nil? || invited?(user)
      friendship.update_attribute(:pending, false)
      return friendship
    end

    # deletes a friendship
    def remove_friendship(user)
      friendship = find_any_friendship_with(user)
      return false if friendship.nil?
      friendship.destroy
      self.reload && user.reload if friendship.destroyed?
    end

    # returns the list of approved friends
    def friends
      invited_ids = self.invited.pluck(:friend_id)
      invited_by_ids = self.invited_by.pluck(:friendable_id)

      self.class.where{
        ( id.in(invited_ids)    ) |
        ( id.in(invited_by_ids) )
      }
    end

    # total # of invited and invited_by without association loading
    def total_friends
      self.invited(false).count + self.invited_by(false).count
    end

    # blocks a friendship
    def block_friend(user)
      friendship = find_any_friendship_with(user)
      return false if friendship.nil? || !friendship.can_block?(self)
      friendship.update_attribute(:blocker, self)
      return friendship
    end

    # unblocks a friendship
    def unblock_friend(user)
      friendship = find_any_friendship_with(user)
      return false if friendship.nil? || !friendship.can_unblock?(self)
      friendship.update_attribute(:blocker, nil)
      return friendship
    end

    # returns the list of blocked friends
    def blocked_friends
      blockade_ids = self.blockades.pluck(:friend_id)
      blockade_by_ids = self.blockades_by.pluck(:friendable_id)

      self.class.where{
        ( id.in(blockade_ids)    ) |
        ( id.in(blockade_by_ids) )
      }
    end

    # total # of blockades and blockedes_by without association loading
    def total_blocked_friends
      self.blockades(false).count + self.blockades_by(false).count
    end

    # checks if a user is blocked
    def blocked_friend?(user)
      blocked.include?(user)
    end

    # checks if a user is a friend
    def friend_with?(user)
      friends.include?(user)
    end

    # checks if a current user is connected to given user
    def connected_with?(user)
      find_any_friendship_with(user).present?
    end

    # checks if a current user received invitation from given user
    def invited_by?(user)
      friendship = find_any_friendship_with(user)
      return false if friendship.nil?
      friendship.friendable_id == user.id
    end

    # checks if a current user invited given user
    def invited?(user)
      friendship = find_any_friendship_with(user)
      return false if friendship.nil?
      friendship.friend_id == user.id
    end

    # return the list of the ones among its friends which are also friend with the given use
    def common_friends_with(user)
      self.friends & user.friends
    end

    # returns friendship with given user or nil
    def find_any_friendship_with(user)
      friendship = Amistad.friendship_class.where(:friendable_id => self.id, :friend_id => user.id).first
      if friendship.nil?
        friendship = Amistad.friendship_class.where(:friendable_id => user.id, :friend_id => self.id).first
      end
      friendship
    end

    #updates the registered status to true for the user in the friendships table
    def update_friendship_registered_status
      Amistad.friendship_class.where(friend_id: self.id).update_all(friend_registered: true)
    end
  end
end
