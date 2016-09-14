/*
 * Copyright 2016 Realm Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.realm.realmtasks.list;

import android.support.v7.widget.RecyclerView;

import java.util.List;

import io.realm.Realm;
import io.realm.RealmList;
import io.realm.realmtasks.model.TaskList;

public class TasksListAdapter extends TasksCommonAdapter<TaskList> {

    public TasksListAdapter(List<TaskList> items) {
        super(items);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        super.onBindViewHolder(holder, position);
        final TasksViewHolder tasksViewHolder = (TasksViewHolder) holder;
        final TaskList taskList = items.get(position);
        tasksViewHolder.getText().setText(taskList.getText());
        tasksViewHolder.setStrike(taskList.isCompleted());
    }

    @Override
    public void onItemAdded() {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                final TaskList taskList = realm.createObject(TaskList.class);
                taskList.setText("Added");
                items.add(0, taskList);
            }
        });
        realm.close();
        super.onItemAdded();
    }

    @Override
    public void onItemMoved(final int fromPosition, final int toPosition) {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                moveItems(fromPosition, toPosition);
            }
        });
        realm.close();
        super.onItemMoved(fromPosition, toPosition);
    }

    @Override
    public void onItemArchived(final int position) {
        final TaskList taskList = items.get(position);
        final Realm realm = Realm.getDefaultInstance();
        final int count = (int) ((RealmList<TaskList>) items).where().equalTo("completed", false).count();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                if (!taskList.isCompleted() && taskList.isCompetable()) {
                    taskList.setCompleted(true);
                    moveItems(position, count - 1);
                } else {
                    taskList.setCompleted(false);
                    moveItems(position, count);
                }
            }
        });
        super.onItemArchived(position);
    }

    @Override
    public void onItemDismissed(final int position) {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                items.remove(position);
            }
        });
        realm.close();
        super.onItemDismissed(position);
    }

    @Override
    public void onItemReverted() {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                items.remove(0);
            }
        });
        realm.close();
        super.onItemReverted();
    }

    @Override
    public void onItemChanged(final TasksViewHolder viewHolder) {
        final Realm realm = Realm.getDefaultInstance();
        final int position = viewHolder.getAdapterPosition();
        if (position < 0) {
            return;
        }
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                TaskList taskList = items.get(position);
                taskList.setText(viewHolder.getText().getText().toString());
            }
        });
        realm.close();
        super.onItemChanged(viewHolder);
    }
}
