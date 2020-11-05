defmodule User do
  #add username to sub box
  #spawn user.run process and add to registry
  def start(user_name) do
    sub_box = %{}
    pid = spawn(fn -> User.run(sub_box) end)
    case :global.register_name(user_name,pid) do
      :yes -> pid
      :no -> IO.puts("User is already in register")
    end
  end

  #find user_name pid and send sub message to that process
  def subscribe(user_name, topic_name)do
    user_pid = :global.whereis_name(user_name)
    send user_pid, {:sub, user_pid, topic_name}
  end

  #find user_name pid and send unsub message to that process 
  def unsubscribe(user_name, topic_name) do
    user_pid = :global.whereis_name(user_name)
    send user_pid, {:unsub, user_pid, topic_name}
  end

  #find user_name pid and send post mesage to that process
  def post(user_name, topic_name, content) do
    user_pid = :global.whereis_name(user_name)
    send user_pid, {:post, user_pid, topic_name, content}
  end

  #find user_name pid and send fetch message to that process
  def fetch_news(user_name) do
    user_pid = :global.whereis_name(user_name)
    send user_pid, {:fetch}
  end

  #message handling 
  def run(sub_box) do
    receive do
      #sub message where if topic doesn't exists yet spawn new topic
      # if topic exists send message to that process to add the user
      {:sub, user_pid, topic_name} -> 
        case :global.whereis_name(topic_name) do
          :undefined -> 
            topic_pid = TopicManager.start(topic_name)
            send topic_pid, {:sub, user_pid, topic_name}
            run(sub_box)
          _ ->
            topic_pid = :global.whereis_name(topic_name)
            send topic_pid, {:sub, user_pid, topic_name}
            run(sub_box)
        end
      #success message recieved from TopicManager, update subbox
      {:success, content, topic_name} ->
        sub_box = Map.put(sub_box, topic_name, content)
        run(sub_box)
      #remove topic from user's sub_box
      {:unsub, user_pid, topic_name} ->
        case :global.whereis_name(topic_name) do
          :undefined -> 
            IO.puts("Topic not found!")
            run(sub_box)
          _ ->
            topic_pid = :global.whereis_name(topic_name)
            send topic_pid, {:unsub, user_pid, topic_name}
            sub_box = Map.delete(sub_box, topic_name)
            run(sub_box)
        end
      #send post message to TopicManager
      {:post, user_pid, topic_name, content} ->
        case :global.whereis_name(topic_name) do
          :undefined -> 
            IO.puts("Topic not found!")
            run(sub_box)
          _ ->
            topic_pid = :global.whereis_name(topic_name)
            send topic_pid, {:post, user_pid, topic_name, content}
            run(sub_box)
        end
      #prints out sub_box
      {:fetch} ->
        IO.inspect(sub_box)
        run(sub_box)
    end
  end
end

defmodule TopicManager do
  #spawn TopicManager.run process and add to global registry
  def start(topic_name) do
    topics = %{content: [], subs: []}
    pid = spawn(fn -> TopicManager.run(topics) end)
    case :global.register_name(topic_name, pid) do
      yes -> pid
      no -> IO.puts("topic is already in register")
    end
  end

  #message handling
  def run(topics) do
    receive do
      #checks if user is subscribed
      #if user isn't in sub list, add user to that list
      #send back the contents of the topic
      {:sub, user_pid, topic_name} ->
        if user_pid in topics[:subs] do
          IO.puts("User is already subscribed!")
          run(topics)
        else
          topics = %{topics | subs: topics[:subs] ++ [user_pid]}
          send user_pid, {:success, topics[:content], topic_name}
          run(topics)
        end
      #remove user from sub list
      {:unsub, user_pid, topic_name} ->
        topics = %{topics | subs: List.delete(topics[:subs], user_pid)}
        send user_pid, {:unsub_user, topic_name}
        run(topics)
      #add user's message to topic
      #send updated content list to all subscribed users
      {:post, user_pid, topic_name, new_content} ->
        if user_pid in topics[:subs] do
          topics = %{topics | content: topics[:content] ++ [new_content]}
          for user_pid <- topics[:subs] do
            send user_pid, {:success, topics[:content], topic_name}
          end
          run(topics)
        else
          IO.puts("User must be subscribed to post!")
          run(topics)
        end
    end
  end
end

#iex --name "a@Jamess-MacBook-Pro.local"