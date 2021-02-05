require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

#1. Skapa ER + databas som kan hålla användare och tider. Fota ER-diagram, 
#   lägg i misc-mapp
#2. Skapa ett formulär för att registrerara användare.
#3. Skapa ett formulär för att logga in. Om användaren lyckas logga  
#   in: Spara information i session som håller koll på att användaren är inloggad
#4. Låt inloggad användare skapa todos i ett formulär (på en ny sida ELLER på sidan som visar todos.).
#5. Låt inloggad användare updatera och ta bort sina formulär.
#6. Lägg till felhantering (meddelande om man skriver in fel user/lösen)

#Hjälpfunktioner
def connect_to_db()
    path = "db/snabbspringning.db"
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

message = ""
link_text = ""
def get_user_id()
    #SÅLÄNGE BARA:
    return -1
    user_id = session[:user_id]
    if user_id == nil
        message = "Du har loggats ut automatiskt efter en viss tid."
        link_text = "Logga in igen"
        redirect('/error')
        return
    end
    return user_id
end

def check_logged_in()
    get_user_id()
end


#NÄSTA GÅNG V.6: Lägg till den funktionen som gör att
#koden i den körs innan varje route (se om inloggad)



get('/') do
    redirect('/home')
end

get('/home') do
    slim(:home)
end


#Categories

get('/categories/') do
    db = connect_to_db()
    categories = db.execute('SELECT * From Categories')
    p categories
    slim(:"categories/index", locals: {categories: categories})
end

get('/categories/:id') do
    category_id = params[:id]
    #Här visar vi alla tider för en viss kategori
    #Vi struntar i times/index eftersom detta fungerar som samma sak nästan
    #Nästa gång: FIXA KONTON, LOGGA IN/REGISTRERA. Sedan: Fixa allt med kategorier så att det går att lägga till /ta bort / redigera
    db = connect_to_db()
    times = db.execute('SELECT * From Times WHERE category_id = ?', category_id)
    slim(:"categories/show", locals: {times: times})
end

get('/categories/new') do
    slim(:"categories/new")
end

post('/categories') do
    kategoriNamn = session[:namn]
    #Kolla att det inte redan finns en kategori med detta namn sen


    user_id = get_user_id()

    db = connect_to_db()
    db.execute('INSERT INTO Categories (name, user_id) VALUES (?, ?)', kategoriNamn, user_id)

end