FactoryGirl.define do
  factory :build_request do
    project
    secret 'f21d8b6521728e1abaf0bea0918995e0'
    ref 'master'
  end
end
