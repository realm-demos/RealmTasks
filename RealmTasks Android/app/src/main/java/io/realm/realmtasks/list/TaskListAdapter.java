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

import android.content.Context;
import android.support.v7.widget.RecyclerView;
import android.widget.Toast;

import java.util.UUID;

import io.realm.OrderedRealmCollection;
import io.realm.Realm;
import io.realm.RealmList;
import io.realm.realmtasks.R;
import io.realm.realmtasks.model.TaskList;

public class TaskListAdapter extends CommonAdapter<TaskList> implements TouchHelperAdapter {

    public TaskListAdapter(Context context, OrderedRealmCollection<TaskList> items) {
        super(context, items);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        super.onBindViewHolder(holder, position);
        final ItemViewHolder itemViewHolder = (ItemViewHolder) holder;
        final TaskList taskList = items.get(position);
        itemViewHolder.getText().setText(taskList.getText());
        itemViewHolder.setStrike(taskList.isCompleted());
        itemViewHolder.setBadgeVisible(true);
        int badgeCount = taskList.getItems().size();
        itemViewHolder.setBadgeCount(badgeCount);
    }

    @Override
    public void onItemAdded() {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                final TaskList taskList = realm.createObject(TaskList.class, UUID.randomUUID().toString());
                taskList.setText("New task list");
                items.add(0, taskList);
            }
        });
        realm.close();
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
    }

    @Override
    public void onItemArchived(final int position) {
        final TaskList taskList = items.get(position);
        final Realm realm = Realm.getDefaultInstance();
        final int count = (int) ((RealmList<TaskList>) items).where().equalTo("completed", false).count();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                if (!taskList.isCompleted()) {
                    if (taskList.isCompletable()) {
                        taskList.setCompleted(true);
                        moveItems(position, count - 1);
                    } else {
                        Toast.makeText(context, R.string.unfinished_items, Toast.LENGTH_SHORT).show();
                    }
                } else {
                    taskList.setCompleted(false);
                    moveItems(position, count);
                }
            }
        });
        realm.close();
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
    }

    @Override
    public void onItemReverted() {
        if (items.size() == 0) {
            return;
        }
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                items.remove(0);
            }
        });
        realm.close();
    }

    @Override
    public int generatedRowColor(int row) {
        return ItemViewHolder.ColorHelper.getColor(ItemViewHolder.ColorHelper.listColors, row, getItemCount());
    }

    @Override
    public void onItemChanged(final ItemViewHolder viewHolder) {
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
    }
}
