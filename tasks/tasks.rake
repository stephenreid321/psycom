
namespace :cleanup do
  task :organisations => :environment do
    Organisation.each { |organisation|
      if organisation.affiliations.count == 0 and !organisation.username and !organisation.location and !organisation.website and !organisation.picture
        organisation.destroy 
      end
    }
  end 
end
task :cleanup => ['cleanup:organisations']

