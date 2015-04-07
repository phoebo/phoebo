FactoryGirl.define do
  factory :broker_task, class: Broker::Task do
    sequence(:id)
    name { |n| "Task #{id}" }

    trait :running do
      run_id { "task-#{id}-1-1427988069527-1-mesos.local-DEFAULT" }
    end
  end

end