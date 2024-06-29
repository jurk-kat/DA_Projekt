import pandas as pd

with open('data/03_weather.csv', mode='r', encoding='Windows 1252') as file: # nepouzivam encodig utf-8, protoze data jsou stazena v jinem.
    text = file.read()
    splited = text.split(",\n")
    weather = "\n".join(splited[3:])

with open('data/weather.csv', mode='w', encoding='utf-8') as output_file:
    print(weather, file=output_file)
    
# Changing the time to type datetime as in all the other tables
weather = pd.read_csv('data/weather.csv')
weather["time"] = pd.to_datetime(weather["time"], errors='coerce')
weather.to_csv('data/weather_datetime.csv')
 