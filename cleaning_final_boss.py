import re
import pandas as pd
import numpy as np
from datetime import timedelta


def split_list_of_lists(data):
    max_distance = 0
    current_distance = 0

    for sublist in data:
        if sublist[0] == "*":
            max_distance = max(max_distance, current_distance)
            current_distance = 0
        else:
            current_distance += 1
    max_distance = max(max_distance, current_distance)

    lists = [[] for _ in range(max_distance + 1)]

    list_index = 0

    first_asterisk = True

    for sublist in data:

        if sublist[0] == "*":
            if not first_asterisk:

                while list_index < len(lists):
                    if lists[0]:
                        empty_string_list = ["" for _ in lists[0][0]]
                    else:
                        empty_string_list = []
                    lists[list_index].append(empty_string_list)
                    list_index += 1

            list_index = 0
            first_asterisk = False

        lists[list_index].append(sublist)

        list_index += 1

    while list_index < len(lists):
        if lists[0]:
            empty_string_list = ["" for _ in lists[0][0]]
        else:
            empty_string_list = []
        lists[list_index].append(empty_string_list)
        list_index += 1

    return lists


def corrections_in_rows(df, updates):
    for row, collumn, value in updates:
        df.loc[row, collumn] = value


def corrections_in_rows_soft(df, updates):
    for row, collumn, value in updates:
        if pd.isna(df.loc[row, collumn]):
            df.loc[row, collumn] = value


def clean_time_columns(dataframe, columns):
    for column in columns:
        dataframe[column] = dataframe[column].str.strip(
        ).str.strip(":").str.strip("?")
    return dataframe


def reformat_time_columns(dataframe, columns):
    for column in columns:
        prvni_pulka = dataframe[column].str.slice(0, 2)
        druha_pulka = dataframe[column].str.slice(2, 5)
        dataframe[column] = prvni_pulka + ":" + druha_pulka
    return dataframe


def expand_rows(row):
    hours = pd.date_range(row["ETA date"], row["ETD date"], freq="h")
    return pd.DataFrame({
        "hourly_timestamp": hours,
        "Date of arrival": row["Date of arrival"],
        "Date of departure": row["Date of departure"],
        "ETA_x": row["ETA_x"],
        "ETD_x": row["ETD_x"],
        "boat": row["boat"],
        "passengers": row["passengers"],
        "quay": row["quay"],
        "agent": row["agent"],
        "weight": row["weight"],
        "lenght": row["lenght"],
    })


whole = []
with open("data/05_shifts.csv", mode="r", encoding="utf-8") as file:
    for line in file:
        line = line.split(",\n")
        if line[0] != ",,,,,,,":
            line[0] = line[0].split(",")
            whole.append(line[0])

head = whole[0]
data = whole[1:]

reg_date = re.compile(r"^\d{1,2}\/\d{1,2}\/\d{4}$")
data_lode = []
for line in data:
    if reg_date.match(line[1]):
        line[0] = "*"
    if line[0] == "" or line[0] == "*":
        data_lode.append(line)

result = split_list_of_lists(data_lode)
flattened_first = [item for sublist in result[0] for item in sublist]
flattened_second = [item for sublist in result[1] for item in sublist]
flattened_third = [item for sublist in result[2] for item in sublist]
flattened_fourth = [item for sublist in result[3] for item in sublist]
flattened_fifth = [item for sublist in result[4] for item in sublist]
flattened_sixth = [item for sublist in result[5] for item in sublist]
flattened_seventh = [item for sublist in result[6] for item in sublist]

shifts = pd.DataFrame({
    "Date": flattened_first,
    "Boat1": flattened_second,
    "Time1": flattened_third,
    "Boat2": flattened_fourth,
    "Time2": flattened_fifth,
    "Boat3": flattened_sixth,
    "Time3": flattened_seventh
})

shifts.replace("", np.nan, inplace=True)
columns_to_check = shifts.columns[2:6]
shifts = shifts.dropna(subset=columns_to_check, how="all")

df1 = shifts[["Date", "Boat1", "Time1"]].rename(
    columns={"Boat1": "Boat", "Time1": "Time"})
df2 = shifts[["Date", "Boat2", "Time2"]].rename(
    columns={"Boat2": "Boat", "Time2": "Time"})
df3 = shifts[["Date", "Boat3", "Time3"]].rename(
    columns={"Boat3": "Boat", "Time3": "Time"})

df_combined = pd.concat([df1, df2, df3])
df_combined = df_combined.dropna(subset=["Boat", "Time"])

shifts = df_combined.sort_values(by=["Date"]).reset_index(drop=True)
# Getting rid of Jewel of the Seas part 2, so it does not later duplicate
shifts = shifts.drop(index=[22], axis=0)

replacements = {
    "Aidabella": "AIDAbella",
    "Aidaluna": "AIDAluna",
    "AidaMar": "AIDAmar",
    "Aidasol": "AIDAsol",
    "Preziosa": "MSC Preziosa",
    "Sverdrup": "Otto Sverdrup",
    "Sverdrup ?": "Otto Sverdrup",
    "Hamburg ?": "Hamburg",
    "Ocean Majesty?": "Ocean Majesty",
    "Mein Schiff": "Mein Schiff 4",
    "Island Princess?": "Island Princess",
    "Nieuw Statendam?": "Nieuw Statendam",
    "Borealis 61'": "Borealis",
    "Europa (Skarsv?g)": "Europa",
    "Pacific World (p1800)": "Pacific World",
    "Queen Viktoria (2200)": "Queen Viktoria",
    "Ambience p1000": "Ambience",
    "MS Marina p600": "MS Marina",
    "Riviera p1258": "Riviera",
    "Preziosa ": "MSC Preziosa",
    "Preziosa": "MSC Preziosa",
    "Ambition?": "Ambition",
    "Greg Mortimer p160": "Greg Mortimer",
    "Vasgo Da Gama": "Vasco Da Gama",
    "Arcadia p2388": "Arcadia",
    "Jewel of the seas": "Jewel of the Seas",
    "Sevens Seas Navigator": "Seven Seas Navigator",
    "Seabourn Oviation": "Seabourn Ovation"
}
shifts["Boat"] = shifts["Boat"].str.strip(" ?")
shifts["Boat"] = shifts["Boat"].replace(replacements)
shifts["Time"] = shifts["Time"].replace({"1400 - 2000 (Anker)": "1400 - 2000"})

shifts[["Month", "Day", "Year"]] = shifts["Date"].str.split("/", expand=True)
shifts["Month"] = shifts["Month"].str.rjust(2, "0")
shifts["Day"] = shifts["Day"].str.rjust(2, "0")
shifts["Date_new"] = shifts["Year"] + "-" + \
    shifts["Month"] + "-" + shifts["Day"]

shifts = shifts.drop(["Month", "Day", "Year", "Date"], axis="columns")

shifts["Time"] = shifts["Time"].str.strip()
shifts[["ETA", "ETD"]] = shifts["Time"].str.split("-", expand=True)

columns_to_clean = ["ETA", "ETD"]
shifts = clean_time_columns(shifts, columns_to_clean)
shifts["ETD"] = shifts["ETD"].replace({"2400": "2359"})

# Filling in ETA for Bolette, which was sent to us via Whatsapp
update = [(40, "ETA", "0900")]
corrections_in_rows(shifts, update)

columns_to_reformat = ["ETA", "ETD"]
shifts = reformat_time_columns(shifts, columns_to_reformat)

shifts.loc[shifts["ETA"] == ":", "ETA"] = ""
shifts.loc[shifts["ETD"] == ":", "ETD"] = ""

shifts = shifts.rename(
    columns={"Boat": "boat", "Time": "time", "Date_new": "date"})

cruises = pd.read_csv("data/01_cruises.csv")
cruises = cruises[["Dato", "ETA", "ETD", "Navn",
                   "Passasjerer", "Kai", "Agent", "Tonn", "Lengde"]]
cruises = cruises.rename(columns={"Dato": "date", "Navn": "boat", "Passasjerer": "passengers",
                         "Kai": "quay", "Tonn": "weight", "Lengde": "lenght", "Agent": "agent"})

update = [
    (16, "ETA", "08:00"),
    (16, "ETD", "17:00"),
    (47, "ETD", "16:00"),
    (49, "ETA", "14:00"),
    (113, "ETD", "23:00")
]

corrections_in_rows_soft(cruises, update)

# Getting rid of all the boats that did not arrive
cruises = cruises.drop(index=[15, 49, 115, 160], axis=0)

cruises["boat"] = cruises["boat"].replace(replacements)

cruises[["Day", "Month", "Year"]] = cruises["date"].str.split(".", expand=True)
cruises["Date of arrival"] = cruises["Year"] + \
    "-" + cruises["Month"] + "-" + cruises["Day"]
cruises["Date of departure"] = cruises["Date of arrival"]
cruises = cruises.drop(["date", "Day", "Month", "Year"], axis="columns")

cruises = cruises[["Date of arrival", "Date of departure", "ETA", "ETD", "boat", "passengers", "quay", "agent",
                   "weight", "lenght"]]

cruises["date"] = cruises["Date of arrival"]

combined = pd.merge(cruises, shifts, on=["date", "boat"], how="outer")

# Replace time in table cruises with time in table shifts if there is any
combined["ETA_x"] = combined["ETA_x"].mask(
    combined["ETA_y"].notna() & (combined["ETA_y"] != ""), combined["ETA_y"])
combined["ETD_x"] = combined["ETD_x"].mask(
    combined["ETD_y"].notna() & (combined["ETD_y"] != ""), combined["ETD_y"])

# loose all the columns no longer needed
combined = combined.drop(["date", "time", "ETA_y", "ETD_y"], axis="columns")

combined["ETA date"] = combined["Date of arrival"] + \
    " " + combined["ETA_x"] + ":00"
combined["ETD date"] = combined["Date of arrival"] + \
    " " + combined["ETD_x"] + ":00"

# change to datetime
combined["ETA date"] = pd.to_datetime(combined["ETA date"], errors="coerce")
combined["ETD date"] = pd.to_datetime(combined["ETD date"], errors="coerce")

# time difference between ETA and ETD: -1 day if the boat stayed over midnight
combined["Time in harbour"] = combined["ETD date"] - combined["ETA date"]

combined["Date of arrival"] = pd.to_datetime(combined["Date of arrival"])
combined["Date of departure"] = pd.to_datetime(combined["Date of departure"])

day_added = combined["Time in harbour"] < "0 days 00:00:00"
combined.loc[day_added,
             "Date of departure"] = combined["Date of departure"] + timedelta(days=1)
combined.loc[day_added, "ETD date"] = combined["ETD date"] + timedelta(days=1)

# Day added to the only exception in dataset - Jewel of the sea
combined.loc[45, "Date of departure"] += timedelta(days=1)
combined.loc[45, "ETD date"] += timedelta(days=1)

# Create hour by hour situation in harbour
combined = pd.concat([expand_rows(row)
                     for index, row in combined.iterrows()], ignore_index=True)

combined = combined.drop(
    ["Date of arrival", "Date of departure", "ETA_x", "ETD_x"], axis="columns")
combined.to_csv("data/harbour_for_realsies.csv", encoding="utf-8")
