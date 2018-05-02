
task :geocode => :environment do
  Account.where(:location.ne => nil).where(:coordinates => nil).each { |a| a.save }
  Organisation.where(:location.ne => nil).where(:coordinates => nil).each { |a| a.save }
end 

namespace :cleanup do
  task :organisations => :environment do
    Organisation.each { |organisation|
      if organisation.affiliations.count == 0 and !organisation.username and !organisation.location and !organisation.website and !organisation.email and !organisation.picture and !organisation.facebook_profile_url and !organisation.twitter_profile_url
        organisation.destroy 
      end
    }
  end 
end
task :cleanup => ['cleanup:organisations']

