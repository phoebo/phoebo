FactoryGirl.define do
  factory :user, aliases: [ :admin_user ] do
    id 1
    name 'Jan Noha'
    username 'jan.noha'
    email 'jan.noha@example.com'
    is_admin true
    avatar_url 'https://gitlab.example.tld/uploads/user/avatar/1/avatar.jpg'
  end

  factory :basic_user, class: User do
    id 2
    name 'Pepa Sadra'
    username 'pepa.sadra'
    email 'pepa.sadra@example.com'
    is_admin false
    avatar_url 'https://gitlab.example.tld/uploads/user/avatar/2/avatar.jpg'
  end
end
