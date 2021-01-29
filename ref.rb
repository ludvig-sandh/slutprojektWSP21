get('/wrong_password') do
    slim(:"error/wrong_password")
  end
  
  get('/username_already_exists') do
    slim(:"error/username_already_exists")
  end
  
  get('/different_passwords') do
    slim(:"error/different_passwords")
  end
  
  get('/already_inlogged') do
    slim(:"error/already_inlogged")
  end
  
  get('/has_logged_out') do
    slim(:"error/has_logged_out")
  end
  
  get('/todo_not_found') do
    slim(:"error/todo_not_found")
  end
  
  get('/login') do
    id = session[:id]
    if id != nil
      redirect('/already_inlogged')
    end
    slim(:login)
  end
  
  post('/login') do
    #Logga in
  
    #Hämta information från formuläret
    username = params[:username]
    password = params[:password]
  
    #Skapa en koppling till databasen
    db = SQLite3::Database.new('db/tododb.db')
    db.results_as_hash = true
    
    #Hämta data om användaren
    result = db.execute('SELECT * FROM users WHERE username = ?', username).first
  
    #Om användarnamnet inte fanns, skriv det till användaren
    if result == nil
      redirect('/wrong_password')
    end
  
    #Det krypterade lösenordet samt id:t för användaren
    pw_digest = result['pwdigest']
    id = result['id']
  
    #Om lösenordet stämmer överens med det sparade salthashet
    if BCrypt::Password.new(pw_digest) == password
      #Logga in, låt användaren komma in till sina todos
      session[:id] = id
      redirect('/todos')
    else
      #Fel lösenord
      redirect('/wrong_password')
    end
  end
  
  get('/register') do
    id = session[:id]
    if id != nil
      redirect('/already_inlogged')
    end
    slim(:register)
  end
  
  post('/register') do
    #Registrera användare
  
    #Hämta information från formuläret
    username = params[:username]
    password = params[:password]
    password_confirmed = params[:password_confirmed]
  
    #Om lösenordet stämmer överens med confirmed password
    if password == password_confirmed
      #Skapa en koppling till databasen
      password_digest = BCrypt::Password.create(password)
      db = SQLite3::Database.new('db/tododb.db')
  
      #Hitta om en användare redan finns med samma användarnamn
      result = db.execute('SELECT id FROM users WHERE username = ?', username).first
      if result != nil
        #Errormeddelande: det finns redan en sådan användare
        redirect('/username_already_exists')
      end
  
      #Annars lägger vi till användaren och det krypterade lösenordet i databasen
      db.execute('INSERT INTO users (username, pwdigest) VALUES (?, ?)', username, password_digest)
  
      #Hitta den nya användarens id
      id = db.execute('SELECT id FROM users WHERE username = ?', username).first
  
      #Om id:t av någon anledning inte hittades så kan vi skicka användaren till '/login'
      if id == nil
        redirect('/login')
      end
  
      #Låter användaren vara 'inloggad' med hjälp av sessions och låter hen komma in i todos
      session[:id] = id.first
      redirect('/todos')
    else
      #Felhantering
      redirect('/different_passwords')
    end
  end
  
  
  get('/todos') do
    #Visa användarens todos
  
    #Hämta id:t hos användaren för att hitta hens todos
    id = session[:id]
  
    #Om det inte fanns något sparat id i sessions måste man först logga in
    if id == nil
      redirect('/has_logged_out')
    end
  
    #Skapa koppling till databasen
    db = SQLite3::Database.new('db/tododb.db')
    db.results_as_hash = true
  
    #Hitta alla todos
    result = db.execute('SELECT * FROM todos WHERE user_id = ?', id)
  
    #Visa dem
    slim(:"todos/index", locals: {todos: result})
  end
  
  get('/todos/new') do
    #Hitta id:t hos användaren
    id = session[:id]
  
    #Om det inte fanns något sparat id i sessions måste man först logga in
    if id == nil
      redirect('/has_logged_out')
    end
  
    slim(:"todos/newtodo")
  end
  
  post('/todos') do
    #Lägger till en todo i databasen
  
    #Hitta id:t hos användaren
    id = session[:id]
  
    #Om det inte fanns något sparat id i sessions måste man först logga in
    if id == nil
      redirect('/has_logged_out')
    end
  
    #Vad skrev användaren in i sin todo?
    todo_content = params[:todo_item]
  
    #Koppling till databasen
    db = SQLite3::Database.new('db/tododb.db')
  
    #Lägger till todo för användar-id
    db.execute('INSERT INTO todos (content, user_id) VALUES (?, ?)', todo_content, id)
  
    #Skickar tillbaka användaren till sin vanliga todo-lista
    redirect('/todos')
  end
  
  get('/todos/:id/edit') do
    #Hitta id:t hos användaren
    id = session[:id]
    
    #Om det inte fanns något sparat id i sessions måste man först logga in
    if id == nil
      redirect('/has_logged_out')
    end
  
    #Hitta id på todo
    todo_id = params[:id]
  
    #Koppling till databasen
    db = SQLite3::Database.new('db/tododb.db')
  
    #Hitta todon med rätt id
    result = db.execute('SELECT content FROM todos WHERE id = ?', todo_id).first
    
    #Om todo inte av någon anledning hittades kan vi skicka felmeddelande
    if result == nil
      redirect('/todo_not_found')
    end
  
    slim(:"todos/edittodo", locals: {id: todo_id, content: result.first})
  end
  
  post('/todos/:id/update') do
    #Uppdatera en todo
  
    #Hitta id:t hos användaren
    user_id = session[:id]
    
    #Om det inte fanns något sparat id i sessions måste man först logga in
    if user_id == nil
      redirect('/has_logged_out')
    end
  
    #Hämta data från formuläret
    todo_id = params[:id]
    content = params[:todo_item]
  
    #Koppling till databas
    db = SQLite3::Database.new('db/tododb.db')
  
    #Uppdaterar content-värdet
    db.execute('UPDATE todos SET content=? WHERE id = ?', content, todo_id)
  
    #Tillbaka
    redirect('/todos')
  end
  
  post('/todos/:id/delete') do
    #Hitta id:t hos användaren
    user_id = session[:id]
    
    #Om det inte fanns något sparat id i sessions måste man först logga in
    if user_id == nil
      redirect('/has_logged_out')
    end
  
    #Hämta data från formuläret
    todo_id = params[:id]
  
    #Koppling till databas
    db = SQLite3::Database.new('db/tododb.db')
  
    #Raderar todo
    db.execute('DELETE FROM todos WHERE id=?', todo_id)
  
    redirect('/todos')
  end
  
  get('/logout') do
    #Rensar session
    session[:id] = nil
    redirect('/login')
  end  